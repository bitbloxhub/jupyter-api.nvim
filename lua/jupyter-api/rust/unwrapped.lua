-- Based on blink.cmp, https://github.com/saghen/blink.cmp/blob/f132267/lua/blink/cmp/fuzzy/rust/init.lua

---@return string
local function get_lib_extension()
	if jit.os:lower() == "mac" or jit.os:lower() == "osx" then
		return ".dylib"
	end
	if jit.os:lower() == "windows" then
		return ".dll"
	end
	return ".so"
end

-- search for the lib in the /target/release directory with and without the lib prefix
-- since MSVC doesn't include the prefix
package.cpath = package.cpath
	.. ";"
	.. debug.getinfo(1).source:match("@?(.*/)")
	.. "../../../target/release/lib?"
	.. get_lib_extension()
	.. ";"
	.. debug.getinfo(1).source:match("@?(.*/)")
	.. "../../../target/release/?"
	.. get_lib_extension()

return require("jupyter_api_nvim")
