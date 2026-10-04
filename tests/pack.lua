local uv = vim.uv or vim.loop
local source = debug.getinfo(1, "S").source:gsub("^@", "")
if source:sub(1, 1) ~= "/" then
	source = vim.fs.joinpath(vim.fn.getcwd(), source)
end
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
package.path = table.concat({ root .. "/lua/?.lua", root .. "/lua/?/init.lua", package.path }, ";")

local temp = assert(uv.fs_mkdtemp(vim.fs.joinpath(uv.os_tmpdir(), "azithro-pack-test-XXXXXX")))
local old_stdpath = vim.fn.stdpath
local old_exists = vim.fn.exists
local old_notify = vim.notify
local old_packlockfile = vim.o.packlockfile
local old_package_path = package.path
local old_pack_module = package.loaded["config.pack"]
package.loaded["config.pack"] = nil
local old_env = vim.env.AZITHRO_PACK_LOCK
local original_bundle

local function path(...)
	return vim.fs.joinpath(temp, ...)
end

local function mkdir(dir)
	assert(vim.fn.mkdir(dir, "p") == 1 or uv.fs_stat(dir), "failed to create " .. dir)
end

local function write_file(filename, data)
	mkdir(vim.fs.dirname(filename))
	local fd, err = uv.fs_open(filename, "w", 420)
	assert(fd, err)
	local written, write_err = uv.fs_write(fd, data, 0)
	assert(written == #data, write_err or "short write")
	assert(uv.fs_close(fd))
end

local function read_file(filename)
	local fd, err = uv.fs_open(filename, "r", 438)
	assert(fd, err)
	local stat = assert(uv.fs_fstat(fd))
	local data = assert(uv.fs_read(fd, stat.size, 0))
	assert(uv.fs_close(fd))
	return data
end

local function lock(rev, src)
	return vim.json.encode({
		plugins = {
			alpha = { rev = rev or "abc123", src = src or "https://example.com/alpha", name = "alpha" },
		},
	})
end

local function expect_error(fn, pattern)
	local ok, err = pcall(fn)
	assert(not ok, "expected operation to fail")
	if pattern then
		assert(tostring(err):find(pattern, 1, true), "unexpected error: " .. tostring(err))
	end
end

local function run()
	local bundle_path = vim.fs.joinpath(root, "nvim-pack-lock.json")
	original_bundle = read_file(bundle_path)
	local config_dir = path("config")
	mkdir(config_dir)
	vim.fn.stdpath = function(which)
		if which == "config" then
			return config_dir
		end
		return path(which)
	end
	vim.env.AZITHRO_PACK_LOCK = nil
	local notices = {}
	vim.notify = function(message, level)
		notices[#notices + 1] = { message = tostring(message), level = level }
	end

	local pack = require("config.pack")
	local active = path("override", "nvim-pack-lock.json")
	vim.fn.exists = function(option)
		if option == "+packlockfile" then
			return 0
		end
		return old_exists(option)
	end
	expect_error(function()
		pack.setup({ path = active })
	end, "packlockfile' support")
	vim.fn.exists = old_exists
	local returned = pack.setup({ path = active })
	assert(returned == active)
	assert(vim.o.packlockfile == active, "packlockfile must be set during setup")
	assert(read_file(active) == original_bundle, "absent override should seed from the bundled lock")

	-- A concurrently-created override wins the seed race and is never overwritten.
	local seed_race = path("seed-race", "nvim-pack-lock.json")
	local fresh_seed = lock("fresh-seed")
	local real_fs_link = uv.fs_link
	uv.fs_link = function(source_path, target_path)
		if target_path == seed_race then
			write_file(seed_race, fresh_seed)
		end
		return real_fs_link(source_path, target_path)
	end
	expect_error(function()
		pack.setup({ path = seed_race })
	end, "appeared during operation")
	uv.fs_link = real_fs_link
	assert(read_file(seed_race) == fresh_seed, "setup seed race overwrote a newly-created lock")

	-- Existing overrides are validated, but are never reseeded or overwritten.
	local preserved = lock("feedface")
	write_file(active, preserved)
	pack.setup({ path = active })
	assert(read_file(active) == preserved, "setup must seed only an absent override")

	-- Invalid JSON and malformed native lock shapes must not be replaced.
	local invalid_contents = {
		"{not json",
		"[]",
		"{\"plugins\": []}",
		"{\"plugins\": {\"alpha\": {\"src\": \"https://example.com\"}}}",
		"{\"plugins\": {\"bad/name\": {\"rev\": \"abc\", \"src\": \"https://example.com\"}}}",
		"{\"plugins\": {\"alpha\": {\"rev\": \"abc\", \"src\": \"https://example.com\", \"name\": \"other\"}}}",
	}
	for index, data in ipairs(invalid_contents) do
		local filename = path("invalid-" .. index .. ".json")
		write_file(filename, data)
		expect_error(function()
			pack.setup({ path = filename })
		end, "invalid")
		expect_error(function()
			pack.export(filename, true)
		end, "invalid")
		assert(read_file(filename) == data, "invalid lock was modified")
	end

	-- The helper refuses directory, symlink, and immutable store destinations.
	local directory_target = path("as-directory")
	mkdir(directory_target)
	expect_error(function()
		pack.setup({ path = directory_target })
	end, "directory")
	local victim = path("victim.json")
	local link = path("linked.json")
	write_file(victim, preserved)
	assert(uv.fs_symlink(victim, link))
	expect_error(function()
		pack.setup({ path = link })
	end, "symlink")
	assert(read_file(victim) == preserved)
	expect_error(function()
		pack.export(link, true)
	end, "symlink")
	expect_error(function()
		pack.setup({ path = "/nix/store/azithro-test-lock.json" })
	end, "store")

	-- Export is no-clobber by default, supports bang, and treats the same file as a no-op.
	pack.setup({ path = active })
	local active_data = lock("deadc0de")
	write_file(active, active_data)
	local checkout = path("checkout", "nvim-pack-lock.json")
	assert(pack.export(checkout))
	assert(read_file(checkout) == active_data)
	local other = lock("badc0ffe")
	write_file(checkout, other)
	expect_error(function()
		pack.export(checkout, false)
	end, "Export!")
	assert(read_file(checkout) == other, "non-bang export clobbered destination")

	-- A writer arriving after the conflict check but before installation wins.
	local concurrent_target = path("concurrent-export.json")
	local concurrent_data = lock("concurrent-write")
	uv.fs_link = function(source_path, target_path)
		if target_path == concurrent_target then
			write_file(concurrent_target, concurrent_data)
		end
		return real_fs_link(source_path, target_path)
	end
	expect_error(function()
		pack.export(concurrent_target, false)
	end, "refusing to overwrite")
	uv.fs_link = real_fs_link
	assert(read_file(concurrent_target) == concurrent_data, "non-bang export clobbered a concurrent writer")

	-- Snapshot checking catches an intervening write to an existing bang target before rename.
	local force_race_data = lock("force-race")
	local real_fs_lstat = uv.fs_lstat
	local checkout_lstats, force_race_injected = 0, false
	uv.fs_lstat = function(filename)
		if filename == checkout then
			checkout_lstats = checkout_lstats + 1
			if checkout_lstats == 5 then
				force_race_injected = true
				write_file(checkout, force_race_data)
			end
		end
		return real_fs_lstat(filename)
	end
	expect_error(function()
		pack.export(checkout, true)
	end, "changed during operation")
	uv.fs_lstat = real_fs_lstat
	assert(force_race_injected, "force race was not injected before the final snapshot check")
	assert(read_file(checkout) == force_race_data, "snapshot check clobbered an intervening writer")
	assert(pack.export(checkout, true))
	assert(read_file(checkout) == active_data)
	assert(pack.export(active, false), "same-file export should be harmless")
	assert(read_file(active) == active_data)

	-- Refresh uses the bundled bytes; a changed existing lock requires force and warns to restart.
	local changed = lock("12345678")
	write_file(active, changed)
	expect_error(function()
		pack.refresh(false)
	end, "Refresh!")
	assert(read_file(active) == changed)
	assert(pack.refresh(true))
	assert(read_file(active) == original_bundle)
	assert(#notices > 0)
	assert(notices[#notices].message:find("RESTART", 1, true))
	assert(notices[#notices].message:find(":ZPack restore", 1, true))

	-- The command surface forwards bang and requires an explicit export target.
	write_file(active, lock("cafebabe"))
	local command_target = path("command-export.json")
	vim.api.nvim_cmd({ cmd = "AzithroLockExport", args = { command_target } }, {})
	assert(read_file(command_target) == read_file(active))
	write_file(command_target, lock("01234567"))
	vim.api.nvim_cmd({ cmd = "AzithroLockExport", bang = true, args = { command_target } }, {})
	assert(read_file(command_target) == read_file(active))

	-- A failed destination write must leave the conflicting parent untouched.
	local parent_file = path("not-a-directory")
	write_file(parent_file, "keep")
	expect_error(function()
		pack.setup({ path = vim.fs.joinpath(parent_file, "lock.json") })
	end, "ENOTDIR")
	assert(read_file(parent_file) == "keep")

	-- The parent-provided environment path is the default override; an explicit argument wins.
	local env_override = path("environment", "native-pack-lock.json")
	vim.env.AZITHRO_PACK_LOCK = env_override
	assert(pack.setup({ path = active }) == active)
	local from_env = pack.setup({})
	assert(from_env == env_override)
	assert(vim.o.packlockfile == env_override)
	assert(read_file(env_override) == original_bundle)
	vim.env.AZITHRO_PACK_LOCK = nil

	-- An immutable default config path is refused with guidance to select the one supported override.
	local test_stdpath = vim.fn.stdpath
	vim.fn.stdpath = function(which)
		if which == "config" then
			return "/nix/store/azithro-config"
		end
		return test_stdpath(which)
	end
	expect_error(function()
		pack.setup({})
	end, "set AZITHRO_PACK_LOCK")
	vim.fn.stdpath = test_stdpath

	-- With no override, use stdpath(config)'s tracked lock and never seed it from the bundle.
	local default_lock = vim.fs.joinpath(config_dir, "nvim-pack-lock.json")
	local default_contents = lock("bead1234")
	write_file(default_lock, default_contents)
	local configured = pack.setup({})
	assert(configured == default_lock)
	assert(vim.o.packlockfile == default_lock)
	assert(read_file(default_lock) == default_contents)
	assert(read_file(bundle_path) == original_bundle, "test changed the tracked bundled lock")
end

local ok, err = xpcall(run, debug.traceback)
vim.fn.stdpath = old_stdpath
vim.fn.exists = old_exists
vim.notify = old_notify
vim.o.packlockfile = old_packlockfile
package.path = old_package_path
package.loaded["config.pack"] = old_pack_module
vim.env.AZITHRO_PACK_LOCK = old_env
pcall(vim.fn.delete, temp, "rf")
if not ok then
	error(err, 0)
end
print("tests/pack.lua: all tests passed")
