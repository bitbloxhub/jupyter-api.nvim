use std::{
	collections::HashMap,
	os::fd::{AsRawFd, RawFd},
	sync::Arc,
};

use mlua::{FromLua, Lua, LuaSerdeExt, Result, Table, UserData, Value};
use once_cell::sync::Lazy;
use runtimelib::{
	Channel, ClientControlConnection, ClientHeartbeatConnection, ClientIoPubConnection,
	ClientShellConnection, ClientStdinConnection, ConnectionInfo, JupyterMessage,
	JupyterMessageContent, create_client_control_connection, create_client_heartbeat_connection,
	create_client_iopub_connection, create_client_shell_connection, create_client_stdin_connection,
	list_kernelspecs,
};
use thiserror::Error;
use tokio::{
	io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
	net::unix::pipe::{Receiver, Sender, pipe},
	runtime::{self},
	select,
};
use uuid::Uuid;

static TOKIO: Lazy<runtime::Runtime> = Lazy::new(|| {
	#[allow(clippy::expect_used)]
	runtime::Builder::new_multi_thread()
		.enable_all()
		.build()
		.expect("cannot start tokio runtime")
});

#[derive(Error, Debug)]
pub enum JupyterApiError {
	#[error("Failed to parse JSON, {0}")]
	SerdeJsonError(#[from] serde_json::Error),
	#[error("runtimelib error, {0}")]
	RuntimelibError(#[from] runtimelib::RuntimeError),
	#[error("IO error, {0}")]
	IOError(#[from] std::io::Error),
	#[error(
		"Error receiving message: No content! (although this should already be caught by now!)"
	)]
	ReceiveNoContentError,
	#[error("Error sending message: no channel!")]
	SendNoChannelError,
	#[error("Error sending message: cannot send to sub channel!")]
	SendSubChannelError,
}

pub struct Connection {
	connection_info: ConnectionInfo,
	session_id: String,
	read_pipe: RawFd,
	write_pipe: RawFd,
}

impl FromLua for Connection {
	fn from_lua(value: Value, _: &Lua) -> Result<Self> {
		match value {
			Value::UserData(ud) => Ok(ud.take()?),
			_ => unreachable!(),
		}
	}
}

impl UserData for Connection {
	fn add_fields<F: mlua::UserDataFields<Self>>(fields: &mut F) {
		fields.add_field_method_get("connection_info", |lua, this| {
			lua.to_value(&this.connection_info)
		});
		fields.add_field_method_get("session_id", |_, this| Ok(this.session_id.clone()));
		fields.add_field_method_get("read_pipe_fd", |_, this| Ok(this.read_pipe));
		fields.add_field_method_get("write_pipe_fd", |_, this| Ok(this.write_pipe));
	}
}

// 7 is the max, We have 9 but dont use 3 of them, mostly so we can hold a reference to them so
//   they do not drop.
#[allow(clippy::too_many_arguments)]
async fn connection_handler(
	_out_pipe_r: Receiver,
	mut out_pipe_w: Sender,
	mut in_pipe_r: BufReader<Receiver>,
	_in_pip_w: Sender,
	mut shell_connection: ClientShellConnection,
	mut iopub_connection: ClientIoPubConnection,
	mut stdin_connection: ClientStdinConnection,
	mut control_connection: ClientControlConnection,
	_heartbeat_connection: ClientHeartbeatConnection,
) -> std::result::Result<(), JupyterApiError> {
	loop {
		let mut pipe_line = String::new();
		select! {
			_pipe_msg = in_pipe_r.read_line(&mut pipe_line) => {
				let mut message = serde_json::from_str::<JupyterMessage>(&pipe_line)?;
				let message_hashmap: HashMap<&str, serde_json::Value> = serde_json::from_str(&pipe_line)?;
				let message_content_value = message_hashmap.get("content").ok_or(JupyterApiError::ReceiveNoContentError)?;
				message.content = JupyterMessageContent::from_type_and_content(&message.header.msg_type, message_content_value.clone())?;
				match message.channel {
					Some(ref channel) => {
						match channel {
							Channel::Shell => { shell_connection.send(message).await? },
							Channel::Stdin => { stdin_connection.send(message).await? },
							Channel::Control => { control_connection.send(message).await? },
							_ => {
								return Err(JupyterApiError::SendSubChannelError);
							}
						}
					},
					None => {
						return Err(JupyterApiError::SendNoChannelError);
					}
				}
			},
			shell_msg = shell_connection.read() => {
				match shell_msg {
					Ok(mut message) => {
						message.channel = Some(Channel::Shell);
						out_pipe_w
							.write_all((serde_json::to_string(&message)? + "\n").as_bytes())
							.await?;
					},
					Err(e) => {
						break Err(e.into());
					},
				}
			}
			iopub_msg = iopub_connection.read() => {
				match iopub_msg {
					Ok(mut message) => {
						message.channel = Some(Channel::IOPub);
						out_pipe_w
							.write_all((serde_json::to_string(&message)? + "\n").as_bytes())
							.await?;
					},
					Err(e) => {
						break Err(e.into());
					},
				}
			}
			stdin_msg = stdin_connection.read() => {
				match stdin_msg {
					Ok(mut message) => {
						message.channel = Some(Channel::Stdin);
						out_pipe_w
							.write_all((serde_json::to_string(&message)? + "\n").as_bytes())
							.await?;
					},
					Err(e) => {
						break Err(e.into());
					},
				}
			}
			control_msg = control_connection.read() => {
				match control_msg {
					Ok(mut message) => {
						message.channel = Some(Channel::Control);
						out_pipe_w
							.write_all((serde_json::to_string(&message)? + "\n").as_bytes())
							.await?;
					},
					Err(e) => {
						break Err(e.into());
					},
				}
			}
		};
		out_pipe_w.flush().await?;
	}
}

async fn connect(lua: Lua, params: Value) -> Result<Connection> {
	let handle = TOKIO.handle();
	let connection_info: ConnectionInfo = lua.from_value(params)?;
	let res = handle
		.spawn(async move {
			let session_id = Uuid::new_v4().to_string();
			let (in_pipe_w, in_pipe_r) = pipe()?;
			let (out_pipe_w, out_pipe_r) = pipe()?;
			let connection = Connection {
				connection_info: connection_info.clone(),
				session_id: session_id.clone(),
				read_pipe: out_pipe_r.as_raw_fd(),
				write_pipe: in_pipe_w.as_raw_fd(),
			};
			let in_pipe_r = BufReader::new(in_pipe_r);
			let shell_connection =
				create_client_shell_connection(&connection_info, &session_id).await?;
			let iopub_connection =
				create_client_iopub_connection(&connection_info, "", &session_id).await?;
			let stdin_connection =
				create_client_stdin_connection(&connection_info, &session_id).await?;
			let control_connection =
				create_client_control_connection(&connection_info, &session_id).await?;
			let heartbeat_connection = create_client_heartbeat_connection(&connection_info).await?;
			handle.spawn(async move {
				let result = connection_handler(
					out_pipe_r,
					out_pipe_w,
					in_pipe_r,
					in_pipe_w,
					shell_connection,
					iopub_connection,
					stdin_connection,
					control_connection,
					heartbeat_connection,
				)
				.await;
				match result {
					Ok(_) => {
						eprintln!("A connection handler returned OK, this should never happen!");
					}
					Err(e) => {
						eprintln!("A connection handler errored! {}", e);
					}
				}
			});
			Ok::<Connection, JupyterApiError>(connection)
		})
		.await;

	#[allow(clippy::expect_used)]
	return match res.expect("Tokio JoinError") {
		Ok(conn) => Ok(conn),
		Err(err) => {
			return Err(mlua::Error::ExternalError(Arc::from(err)));
		}
	};
}

async fn list_kernels(lua: Lua, _: Value) -> Result<Value> {
	let handle = TOKIO.handle();
	let res = handle.spawn(async move { list_kernelspecs().await }).await;

	#[allow(clippy::expect_used)]
	return lua.to_value(&res.expect("Tokio JoinError"));
}

#[mlua::lua_module]
fn jupyter_api_nvim(lua: &Lua) -> Result<Table> {
	let exports = lua.create_table()?;
	exports.set("connect", lua.create_async_function(connect)?)?;
	exports.set("list_kernels", lua.create_async_function(list_kernels)?)?;

	exports.set(
		"PENDING",
		lua.create_async_function(|_, ()| async move {
			tokio::task::yield_now().await;
			Ok(())
		})?,
	)?;
	Ok(exports)
}
