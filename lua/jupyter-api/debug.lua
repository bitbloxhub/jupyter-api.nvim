local jupyter_api = require("jupyter-api")
local M = {}

M.connect_params = {
	ip = "127.0.0.1",
	transport = "tcp",
	shell_port = 6767,
	iopub_port = 6768,
	stdin_port = 6790,
	control_port = 6791,
	hb_port = 6792,
	key = "secret_key",
	signature_scheme = "hmac-sha256",
}

M.debug_notify = function()
	jupyter_api.connect(M.connect_params, function(_, set_read_callback, send)
		set_read_callback(function(err, data)
			print(err)
			print(vim.json.encode(data))
		end)
		send({
			header = {
				msg_id = "08a7c128-9689-47f9-b362-0d5e27de6d1c",
				username = "runtimelib",
				session = "aeb58f06-c157-4474-b0d1-e4725f3cf64c",
				date = "2025-12-01T17:52:01.426359883Z",
				msg_type = "execute_request",
				version = "5.3",
			},
			parent_header = vim.NIL,
			metadata = vim.empty_dict(),
			content = {
				code = "console.log('hello world')",
				silent = false,
				store_history = true,
				user_expressions = vim.empty_dict(),
				allow_stdin = false,
				stop_on_error = true,
			},
			channel = "shell",
		})
	end)
end

M.debug_list_kernels = function()
	jupyter_api.list_kernels(function(kernels)
		print(vim.json.encode(kernels))
	end)
end

return M
