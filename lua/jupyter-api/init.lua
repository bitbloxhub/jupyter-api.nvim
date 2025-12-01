local jupyter_api_nvim = require("jupyter-api.rust")

local M = {}

---Connect to a jupyter kernel
---@type fun(connection_info: JupyterConnectionInfo, callback: fun(conn: JupyterConnection, set_read_callback: fun(read_callback: fun(err, data)), send: fun(message: JupyterMessage)))
M.connect = function(connection_info, callback)
	jupyter_api_nvim.connect(connection_info, function(conn)
		local read_callback = nil
		local read_pipe = vim.uv.new_pipe()
		assert(read_pipe ~= nil)
		read_pipe:open(conn.read_pipe_fd)
		read_pipe:read_start(function(err, data)
			assert(read_callback, "Was sent a message with no read callback!\nThe message: " .. data)
			if data then
				data = vim.json.decode(data)
			end
			read_callback(err, data)
		end)
		local write_pipe = vim.uv.new_pipe()
		assert(write_pipe ~= nil)
		write_pipe:open(conn.write_pipe_fd)
		callback(conn, function(new_read_callback)
			read_callback = new_read_callback
		end, function(message)
			write_pipe:write(vim.json.encode(message) .. "\n")
		end)
	end)
end

return M
