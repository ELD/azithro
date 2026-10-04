local uv = vim.uv or vim.loop
local source = debug.getinfo(1, "S").source:gsub("^@", "")
if source:sub(1, 1) ~= "/" then
	source = vim.fs.joinpath(vim.fn.getcwd(), source)
end
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
local canonical_bundle = vim.fs.joinpath(root, "nvim-pack-lock.json")
local temp = assert(uv.fs_mkdtemp(vim.fs.joinpath(uv.os_tmpdir(), "azithro-pack-integration-XXXXXX")))
local readonly_paths = {}
local canonical_bytes

local function path(...)
	return vim.fs.joinpath(temp, ...)
end

local function mkdir(dir)
	local result = vim.fn.mkdir(dir, "p")
	assert(result == 1 or uv.fs_stat(dir), "failed to create " .. dir)
end

local function write_file(filename, data)
	mkdir(vim.fs.dirname(filename))
	local fd, err = uv.fs_open(filename, "w", 420)
	assert(fd, err)
	local offset = 0
	while offset < #data do
		local written, write_err = uv.fs_write(fd, data:sub(offset + 1), offset)
		assert(written and written > 0, write_err or "short write")
		offset = offset + written
	end
	assert(uv.fs_close(fd))
end

local function read_file(filename)
	local fd, err = uv.fs_open(filename, "r", 438)
	assert(fd, err)
	local stat = assert(uv.fs_fstat(fd))
	local data, read_err = uv.fs_read(fd, stat.size, 0)
	assert(data, read_err)
	assert(uv.fs_close(fd))
	return data
end

local function run_process(argv, opts)
	local result = vim.system(argv, opts):wait()
	assert(result.code == 0, table.concat({
		"command failed (exit " .. tostring(result.code) .. "): " .. table.concat(argv, " "),
		result.stdout or "",
		result.stderr or "",
	}, "\n"))
	return result.stdout or ""
end

local function git(repo, args)
	assert(repo == temp or repo:sub(1, #temp + 1) == temp .. "/", "Git fixture is outside disposable temp dir")
	local argv = { "git" }
	vim.list_extend(argv, args)
	local env = vim.fn.environ()
	for name in pairs(env) do
		if name:match("^GIT_") then
			env[name] = nil
		end
	end
	env.HOME = path("home")
	env.XDG_CONFIG_HOME = path("git-config")
	env.TMPDIR = temp
	env.GIT_CONFIG_GLOBAL = "/dev/null"
	env.GIT_CONFIG_NOSYSTEM = "1"
	env.GIT_TERMINAL_PROMPT = "0"
	env.GIT_ALLOW_PROTOCOL = "file"
	return run_process(argv, {
		cwd = repo,
		text = true,
		env = env,
		clear_env = true,
	})
end

local function make_readonly(filename, mode)
	local stat = assert(uv.fs_stat(filename), "missing read-only fixture path: " .. filename)
	readonly_paths[#readonly_paths + 1] = { path = filename, mode = stat.mode % 4096 }
	assert(uv.fs_chmod(filename, mode))
end

local function restore_permissions()
	for index = #readonly_paths, 1, -1 do
		local item = readonly_paths[index]
		pcall(uv.fs_chmod, item.path, item.mode)
	end
	readonly_paths = {}
end

local function lockfile(rev, plugin_src)
	return vim.json.encode({
		plugins = {
			["fixture-plugin"] = { rev = rev, src = plugin_src },
		},
	}) .. "\n"
end

local function child_script(config_home, plugin_src, rev1, rev2, lock_path, export_path, phase)
	local constants = table.concat({
		"local config_home = " .. string.format("%q", config_home),
		"local plugin_src = " .. string.format("%q", plugin_src),
		"local rev1 = " .. string.format("%q", rev1),
		"local rev2 = " .. string.format("%q", rev2),
		"local lock_path = " .. string.format("%q", lock_path),
		"local export_path = " .. string.format("%q", export_path),
		"local bundle_path = vim.fs.joinpath(config_home, 'nvim-pack-lock.json')",
		"local plugin_name = 'fixture-plugin'",
		"package.path = vim.fs.joinpath(config_home, 'lua', '?.lua') .. ';' .. vim.fs.joinpath(config_home, 'lua', '?', 'init.lua') .. ';' .. package.path",
		"local uv = vim.uv or vim.loop",
		[=[
local function read_file(filename)
  local fd, err = uv.fs_open(filename, 'r', 438)
  assert(fd, err)
  local stat = assert(uv.fs_fstat(fd))
  local data, read_err = uv.fs_read(fd, stat.size, 0)
  assert(data, read_err)
  assert(uv.fs_close(fd))
  return data
end
local function read_lock(filename)
  local data = vim.json.decode(read_file(filename))
  assert(type(data) == 'table' and type(data.plugins) == 'table', 'invalid native lockfile: ' .. filename)
  return data.plugins[plugin_name]
end
local function git_head(directory)
  local result = vim.system({ 'git', 'rev-parse', 'HEAD' }, { cwd = directory, text = true }):wait()
  assert(result.code == 0, result.stderr or 'git rev-parse failed')
  return (result.stdout or ''):gsub('%s+$', '')
end
local function installed_plugin(expected_rev, expected_description)
  local items = vim.pack.get({ plugin_name }, { info = true, offline = true })
  assert(#items == 1, 'expected exactly one installed native plugin')
  local plugin = items[1]
  local data_root = vim.fs.normalize(vim.fn.stdpath('data')) .. '/'
  assert(vim.fs.normalize(plugin.path):sub(1, #data_root) == data_root, 'plugin was installed outside disposable XDG data')
  assert(git_head(plugin.path) == expected_rev, 'unexpected installed Git HEAD')
  assert(plugin.manifest and plugin.manifest.name == plugin_name, 'native plugin manifest was not read')
  assert(plugin.manifest.description == expected_description, 'unexpected manifest description')
  return plugin
end
local spec = { { src = plugin_src, name = plugin_name } }
local function assert_isolated_stdpaths()
  assert(vim.fs.normalize(vim.fn.stdpath('config')) == vim.fs.joinpath(config_home, 'nvim'), 'child config path is not disposable')
  assert(vim.fs.normalize(vim.fn.stdpath('data')) == vim.fs.joinpath(vim.env.XDG_DATA_HOME, 'nvim'), 'child data path is not disposable')
  assert(vim.fs.normalize(vim.fn.stdpath('state')) == vim.fs.joinpath(vim.env.XDG_STATE_HOME, 'nvim'), 'child state path is not disposable')
end
assert_isolated_stdpaths()
assert(uv.fs_stat(vim.uri_to_fname(plugin_src)), 'local Git fixture is missing: ' .. plugin_src)
]=],
	}, "\n")

	local phase_code = {
		install = [=[
local pack = require('config.pack')
assert(pack.setup() == lock_path, 'config.pack did not use the state override')
assert(read_file(lock_path) == read_file(bundle_path), 'early setup did not seed the native lock from the bundle')
vim.pack.add(spec, { confirm = false })
local plugin = installed_plugin(rev1, 'fixture revision one')
assert(read_lock(lock_path).rev == rev1, 'vim.pack.add did not retain the bundled pinned revision')
print('installed pinned fixture revision ' .. rev1 .. ' at ' .. plugin.path)
]=],
		update = [=[
local pack = require('config.pack')
assert(pack.setup() == lock_path, 'config.pack did not use the state override')
vim.pack.add(spec, { confirm = false })
installed_plugin(rev1, 'fixture revision one')
vim.pack.update({ plugin_name }, { force = true, offline = true })
installed_plugin(rev2, 'fixture revision two')
assert(read_lock(lock_path).rev == rev2, 'offline native update did not write the newer revision')
assert(pack.export(export_path, true), 'native lock export failed')
assert(read_lock(export_path).rev == rev2, 'export did not contain the updated native revision')
print('updated offline to fixture revision ' .. rev2 .. ' and exported the lock')
]=],
		refresh = [=[
local pack = require('config.pack')
assert(pack.setup() == lock_path, 'config.pack did not use the state override')
assert(read_lock(lock_path).rev == rev2, 'refresh phase did not start with the updated lock')
assert(pack.refresh(true), 'bundled lock refresh failed')
assert(read_lock(lock_path).rev == rev1, 'refresh did not restore the bundled revision')
assert(read_lock(export_path).rev == rev2, 'refresh changed the exported update')
print('refreshed the state lock from the read-only bundled config')
]=],
		restore = [=[
local pack = require('config.pack')
assert(pack.setup() == lock_path, 'config.pack did not use the state override')
assert(read_lock(lock_path).rev == rev1, 'restore restart did not load the refreshed bundled lock')
vim.pack.add(spec, { confirm = false })
installed_plugin(rev2, 'fixture revision two')
vim.pack.update({ plugin_name }, { force = true, offline = true, target = 'lockfile' })
local plugin = installed_plugin(rev1, 'fixture revision one')
assert(read_lock(lock_path).rev == rev1, 'native target=lockfile restore changed the pinned revision')
assert(read_lock(export_path).rev == rev2, 'native restore changed the exported update')
print('restored native plugin to bundled revision ' .. rev1 .. ' at ' .. plugin.path)
]=],
	}
	return constants .. "\n" .. assert(phase_code[phase], "unknown integration phase")
end

local function run()
	assert(vim.fn.executable("git") == 1, "git is required for the native pack integration test")
	local nvim = vim.v.progpath
	assert(nvim and nvim ~= "" and vim.fn.executable(nvim) == 1, "cannot locate the installed Neovim executable")
	canonical_bytes = read_file(canonical_bundle)

	local config_home = path("config")
	local config_dir = vim.fs.joinpath(config_home, "nvim")
	local lua_dir = vim.fs.joinpath(config_home, "lua")
	local lua_config_dir = vim.fs.joinpath(lua_dir, "config")
	local data_home = path("data")
	local state_home = path("state")
	local cache_home = path("cache")
	local home = path("home")
	local scripts_dir = path("scripts")
	local plugin_repo = path("fixture-plugin")
	local plugin_src = vim.uri_from_fname(plugin_repo)
	local lock_path = vim.fs.joinpath(state_home, "native-pack-lock.json")
	local export_path = path("exported", "nvim-pack-lock.json")
	for _, dir in ipairs({ config_dir, lua_config_dir, data_home, state_home, cache_home, home, scripts_dir, plugin_repo }) do
		mkdir(dir)
	end

	write_file(vim.fs.joinpath(lua_config_dir, "pack.lua"), read_file(vim.fs.joinpath(root, "lua", "config", "pack.lua")))

	git(plugin_repo, { "init" })
	git(plugin_repo, { "checkout", "-B", "main" })
	write_file(vim.fs.joinpath(plugin_repo, "pkg.json"), vim.json.encode({
		name = "fixture-plugin",
		description = "fixture revision one",
		engines = { nvim = ">=0.12.0" },
	}) .. "\n")
	write_file(vim.fs.joinpath(plugin_repo, "marker.txt"), "revision one\n")
	git(plugin_repo, { "add", "pkg.json", "marker.txt" })
	git(plugin_repo, {
		"-c", "user.name=Azithro integration test",
		"-c", "user.email=azithro-integration@example.invalid",
		"commit", "-m", "fixture revision one",
	})
	local rev1 = git(plugin_repo, { "rev-parse", "HEAD" }):gsub("%s+$", "")

	write_file(vim.fs.joinpath(plugin_repo, "pkg.json"), vim.json.encode({
		name = "fixture-plugin",
		description = "fixture revision two",
		engines = { nvim = ">=0.12.0" },
	}) .. "\n")
	write_file(vim.fs.joinpath(plugin_repo, "marker.txt"), "revision two\n")
	git(plugin_repo, { "add", "pkg.json", "marker.txt" })
	git(plugin_repo, {
		"-c", "user.name=Azithro integration test",
		"-c", "user.email=azithro-integration@example.invalid",
		"commit", "-m", "fixture revision two",
	})
	local rev2 = git(plugin_repo, { "rev-parse", "HEAD" }):gsub("%s+$", "")
	assert(rev1 ~= rev2, "fixture commits must have distinct revisions")

	local bundle_path = vim.fs.joinpath(config_home, "nvim-pack-lock.json")
	write_file(bundle_path, lockfile(rev1, plugin_src))

	-- The code and bundled lock mimic an immutable installed config. The writable
	-- native lock override lives in XDG_STATE_HOME instead of this tree.
	for _, filename in ipairs({
		vim.fs.joinpath(lua_config_dir, "pack.lua"),
		bundle_path,
	}) do
		make_readonly(filename, 292) -- 0444
	end
	for _, dir in ipairs({ lua_config_dir, lua_dir, config_dir, config_home }) do
		make_readonly(dir, 365) -- 0555
	end

	local child_env = vim.fn.environ()
	for name in pairs(child_env) do
		if name:match("^GIT_") or name:match("^AZITHRO_") then
			child_env[name] = nil
		end
	end
	child_env.HOME = home
	child_env.XDG_CONFIG_HOME = config_home
	child_env.XDG_DATA_HOME = data_home
	child_env.XDG_STATE_HOME = state_home
	child_env.XDG_CACHE_HOME = cache_home
	child_env.TMPDIR = temp
	child_env.AZITHRO_PACK_LOCK = lock_path
	child_env.NVIM_APPNAME = nil
	child_env.GIT_CONFIG_GLOBAL = "/dev/null"
	child_env.GIT_CONFIG_NOSYSTEM = "1"
	child_env.GIT_TERMINAL_PROMPT = "0"
	child_env.GIT_ALLOW_PROTOCOL = "file"
	for _, phase in ipairs({ "install", "update", "refresh", "restore" }) do
		local script = vim.fs.joinpath(scripts_dir, phase .. ".lua")
		write_file(script, child_script(config_home, plugin_src, rev1, rev2, lock_path, export_path, phase))
		-- Keep native Git pack subprocesses' inherited cwd disposable: relative object
		-- paths (including the observed `false/pack`) must not resolve against the checkout.
		local result = vim.system({ nvim, "--headless", "-u", "NONE", "-n", "-i", "NONE", "-l", script }, {
			cwd = temp,
			text = true,
			env = child_env,
			clear_env = true,
		}):wait()
		assert(result.code == 0, table.concat({
			"Neovim integration phase '" .. phase .. "' failed (exit " .. tostring(result.code) .. ")",
			result.stdout or "",
			result.stderr or "",
		}, "\n"))
	end

	assert(read_file(canonical_bundle) == canonical_bytes, "integration test modified the canonical bundled lock")
	assert(read_file(bundle_path) == lockfile(rev1, plugin_src), "integration test modified its read-only bundled lock")
	assert(read_file(export_path) ~= "", "exported native lock is missing")
	local version = (vim.fn.execute("version"):match("NVIM [^\n]+") or "Neovim " .. vim.inspect(vim.version()))
	print("tests/pack-integration.lua: all tests passed (" .. version .. ")")
end

local ok, err = xpcall(run, debug.traceback)
restore_permissions()
pcall(vim.fn.delete, temp, "rf")
if canonical_bytes then
	local read_ok, current = pcall(read_file, canonical_bundle)
	if not read_ok or current ~= canonical_bytes then
		ok = false
		err = "integration test changed the canonical bundled lock"
	end
end
if not ok then
	error(err, 0)
end
