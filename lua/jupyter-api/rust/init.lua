-- Based on neorg-query, https://github.com/benlubas/neorg-query/blob/e32b2de/lua/neorg_query/api.lua

local jupyter_api_nvim = require("jupyter-api.rust.unwrapped")

local M = {}

local PENDING = (coroutine.wrap(jupyter_api_nvim.PENDING))()

---Wrap an async rust function in a coroutine that neovim will poll. Return a function that takes
---function args and a callback function
---@param async_fn any
---@return fun(args: ...)
local wrap = function(async_fn)
	return function(...)
		local args = { ... }
		local cb = args[#args]
		args[#args] = nil

		local thread = coroutine.wrap(async_fn)
		local exec
		exec = function()
			local res = thread(unpack(args))
			if res == PENDING then
				vim.defer_fn(exec, 10)
			else
				cb(res)
			end
		end
		vim.schedule(exec)
	end
end

---From https://docs.rs/runtimelib/0.30.0/runtimelib/connection/struct.Header.html
---@class JupyterHeader
---@field msg_id string
---@field username string
---@field session string
---@field date string
---@field msg_type string
---@field version string

---TODO: create types for this
---@alias JupyterMessageContent any

---From https://docs.rs/runtimelib/0.30.0/runtimelib/connection/enum.Channel.html
---@enum JupyterChannel
M.jupyter_channel = {
	shell = "shell",
	control = "control",
	stdin = "stdin",
	iopub = "iopub",
	heartbeat = "heartbeat",
}

---From https://docs.rs/runtimelib/0.30.0/runtimelib/connection/struct.JupyterMessage.html
---@class JupyterMessage
---@field header JupyterHeader
---@field parent_header JupyterHeader | nil
---@field metadata any
---@field content JupyterMessageContent
---@field channel JupyterChannel

---From https://docs.rs/runtimelib/0.30.0/runtimelib/connection/struct.ConnectionInfo.html
---@class JupyterConnectionInfo
---@field ip string
---@field transport "ipc" | "tcp"
---@field shell_port integer
---@field iopub_port integer
---@field stdin_port integer
---@field control_port integer
---@field hb_port integer
---@field key string
---@field signature_scheme string
---@field kernel_name string | nil

---@class JupyterConnection
---@field connection_info JupyterConnectionInfo,
---@field session_id string
---@field read_pipe_fd integer
---@field write_pipe_fd integer

---Connect to a jupyter kernel
---@type fun(connection_info: JupyterConnectionInfo, callback: fun(conn: JupyterConnection))
M.connect = wrap(jupyter_api_nvim.connect)

M.connect_example_params = {
	ip = "127.0.0.1",
	transport = "tcp",
	shell_port = 6767,
	iopub_port = 6768,
	stdin_port = 6790,
	control_port = 6791,
	hb_port = 6792,
	key = "secret_key",
	signature_scheme = "hmac-sha256",
	kernel_name = "python3",
}

return M
