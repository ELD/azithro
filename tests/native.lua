local source = debug.getinfo(1, "S").source:gsub("^@", "")
if source:sub(1, 1) ~= "/" then
	source = vim.fs.joinpath(vim.fn.getcwd(), source)
end
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
local spec_path = vim.fs.joinpath(root, "lua", "plugins", "blink", "pairs.lua")

local state = {}
local pairs = {
	library_available = function()
		return state.available
	end,
	download = function()
		state.downloads = state.downloads + 1
		return {
			pwait = function(_, timeout)
				state.timeouts[#state.timeouts + 1] = timeout
				if state.result then
					state.available = true
				end
				return state.result, state.download_error
			end,
		}
	end,
	setup = function(opts)
		state.setup_calls = state.setup_calls + 1
		state.setup_opts = opts
	end,
}
package.loaded["blink.pairs"] = nil
package.preload["blink.pairs"] = function()
	return pairs
end

local spec = dofile(spec_path)
assert(type(spec.build) == "function", "blink.pairs build hook is missing")
assert(type(spec.config) == "function", "blink.pairs config hook is missing")

local function reset(available, result, download_error)
	state.available = available
	state.result = result
	state.download_error = download_error
	state.downloads = 0
	state.timeouts = {}
	state.setup_calls = 0
	state.setup_opts = nil
end

-- vim.pack.add installs the entire lock before ZPack build hooks are registered.
-- The config hook therefore needs to download the first-install native library.
reset(false, true)
local first_install_opts = { marker = "first-install", nested = { enabled = true } }
spec.config({}, first_install_opts)
assert(state.downloads == 1, "first-install config did not download the native library")
assert(state.timeouts[1] == 60000, "first-install download did not use the expected timeout")
assert(state.available, "first-install download did not make the library available")
assert(state.setup_calls == 1 and state.setup_opts == first_install_opts, "config did not forward opts to pairs.setup")

-- An installed library must not cause a redundant download.
reset(true, true)
local existing_opts = { marker = "already-installed" }
spec.config({}, existing_opts)
assert(state.downloads == 0, "config downloaded when the native library already existed")
assert(state.setup_calls == 1 and state.setup_opts == existing_opts, "existing-library config did not forward opts")

-- Failed downloads must throw, rather than silently proceeding to setup.
reset(false, false, "release server returned HTTP 503")
local config_ok, config_err = pcall(spec.config, {}, { marker = "download-failure" })
assert(not config_ok, "config accepted a false pwait result")
assert(tostring(config_err):find("blink.pairs native library download failed", 1, true),
	"config failure did not explain the native download error: " .. tostring(config_err))
assert(state.setup_calls == 0, "pairs.setup ran after a failed download")

-- The registered ZPack build hook uses the same ensure-library path.
reset(false, true)
spec.build()
assert(state.downloads == 1 and state.available, "build hook did not ensure the native library")
assert(state.timeouts[1] == 60000, "build hook did not use the expected download timeout")

reset(false, false, "offline")
local build_ok, build_err = pcall(spec.build)
assert(not build_ok, "build hook accepted a false pwait result")
assert(tostring(build_err):find("blink.pairs native library download failed", 1, true),
	"build failure did not explain the native download error: " .. tostring(build_err))

print("tests/native.lua: blink.pairs native setup hooks passed")
