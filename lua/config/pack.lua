local uv = vim.uv or vim.loop

local M = {}
local configured_path
local temp_counter = 0

local source_file = debug.getinfo(1, "S").source:gsub("^@", "")
if source_file:sub(1, 1) ~= "/" then
	source_file = vim.fs.joinpath(vim.fn.getcwd(), source_file)
end
local bundled_lock = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(source_file), "..", "..", "nvim-pack-lock.json"))

local function fail(message)
	error("config.pack: " .. message, 0)
end

local function absolute_path(path, label)
	if type(path) ~= "string" or path == "" or path:find("%z") or path:sub(1, 1) ~= "/" then
		fail((label or "path") .. " must be an absolute filename")
	end
	local normalized = vim.fs.normalize(path)
	if normalized == "/" or vim.fs.basename(normalized) == "" or vim.fs.basename(normalized) == "." then
		fail((label or "path") .. " must name a file")
	end
	return normalized
end

local function missing_error(err)
	return err and (err:match("^ENOENT:") or err:match("^ENOENT$")) ~= nil
end

local function lstat(path)
	local stat, err = uv.fs_lstat(path)
	if stat then
		return stat
	end
	if missing_error(err) then
		return nil
	end
	fail("cannot inspect " .. path .. ": " .. tostring(err))
end

local function is_store_path(path)
	return path == "/nix/store" or path:sub(1, 11) == "/nix/store/"
		or path == "/gnu/store" or path:sub(1, 11) == "/gnu/store/"
end

local function real_path(path)
	local resolved = uv.fs_realpath(path)
	if resolved then
		return vim.fs.normalize(resolved)
	end
	local parent = uv.fs_realpath(vim.fs.dirname(path))
	if parent then
		return vim.fs.normalize(vim.fs.joinpath(parent, vim.fs.basename(path)))
	end
	return path
end

local function check_target(path)
	path = absolute_path(path)
	if is_store_path(path) or is_store_path(real_path(path)) then
		fail("refusing immutable store target: " .. path)
	end
	local stat = lstat(path)
	if stat then
		if stat.type == "link" then
			fail("refusing symlink target: " .. path)
		elseif stat.type == "directory" then
			fail("refusing directory target: " .. path)
		elseif stat.type ~= "file" then
			fail("refusing non-regular target: " .. path)
		end
	end
	return path, stat
end

local function read_file(path, allow_store_source)
	local path_checked, stat
	if allow_store_source then
		path_checked = absolute_path(path)
		stat = uv.fs_stat(path_checked)
		if not stat then
			return nil
		end
		if stat.type ~= "file" then
			fail("bundled lock is not a regular file: " .. path_checked)
		end
	else
		path_checked, stat = check_target(path)
		if not stat then
			return nil
		end
	end
	local fd, err = uv.fs_open(path_checked, "r", 438)
	if not fd then
		fail("cannot open " .. path_checked .. ": " .. tostring(err))
	end
	local chunks, offset = {}, 0
	while offset < stat.size do
		local chunk, read_err = uv.fs_read(fd, math.min(65536, stat.size - offset), offset)
		if not chunk or #chunk == 0 then
			pcall(uv.fs_close, fd)
			fail("cannot read " .. path_checked .. ": " .. tostring(read_err or "unexpected end of file"))
		end
		chunks[#chunks + 1] = chunk
		offset = offset + #chunk
	end
	local close_ok, close_err = uv.fs_close(fd)
	if not close_ok then
		fail("cannot close " .. path_checked .. ": " .. tostring(close_err))
	end
	return table.concat(chunks)
end

local function object(value)
	return type(value) == "table" and not vim.islist(value)
end

local function valid_string(value, max_length)
	return type(value) == "string" and #value > 0 and #value <= max_length
		and not value:find("[%z\1-\31\127]")
end

local function validate_lock(data, path)
	local ok, decoded = pcall(vim.json.decode, data)
	if not ok then
		fail("invalid JSON in " .. path .. ": " .. tostring(decoded))
	end
	if not object(decoded) or not object(decoded.plugins) then
		fail("invalid lock in " .. path .. ": expected a JSON object with a plugins object")
	end
	for name, plugin in pairs(decoded.plugins) do
		if not valid_string(name, 255) or name == "." or name == ".." or name:find("[/\\]") then
			fail("invalid plugin name in " .. path)
		end
		if not object(plugin) then
			fail("invalid plugin entry " .. name .. " in " .. path .. ": expected an object")
		end
		if not valid_string(plugin.rev, 256) or plugin.rev:find("%s") or not valid_string(plugin.src, 4096) then
			fail("invalid plugin entry " .. name .. " in " .. path .. ": rev and src must be non-empty strings")
		end
		if plugin.name ~= nil and (not valid_string(plugin.name, 255) or plugin.name ~= name) then
			fail("invalid plugin entry " .. name .. " in " .. path .. ": name must match its key")
		end
	end
	return decoded
end

local function validated_file(path, required, allow_store_source)
	local data = read_file(path, allow_store_source)
	if data == nil then
		if required then
			fail("lockfile does not exist: " .. path)
		end
		return nil
	end
	validate_lock(data, path)
	return data
end

local function same_stat(a, b)
	if not a or not b then
		return a == b
	end
	for _, key in ipairs({ "dev", "ino", "mode", "size" }) do
		if a[key] ~= b[key] then
			return false
		end
	end
	for _, key in ipairs({ "mtime", "ctime" }) do
		local at, bt = a[key] or {}, b[key] or {}
		if at.sec ~= bt.sec or at.nsec ~= bt.nsec then
			return false
		end
	end
	return true
end

local function file_snapshot(path)
	local checked_path, before = check_target(path)
	if not before then
		return nil
	end
	local data = read_file(checked_path)
	local _, after = check_target(checked_path)
	if not data or not after or not same_stat(before, after) then
		fail("lockfile changed while being inspected: " .. checked_path)
	end
	return { data = data, stat = after }
end

local function same_snapshot(a, b)
	if not a or not b then
		return a == b
	end
	return a.data == b.data and same_stat(a.stat, b.stat)
end

local function mkdir_parent(path)
	local parent = vim.fs.dirname(path)
	local stat = lstat(parent)
	if not stat then
		local result = vim.fn.mkdir(parent, "p")
		if result == 0 and not lstat(parent) then
			fail("cannot create parent directory: " .. parent)
		end
		stat = lstat(parent)
	end
	if not stat or stat.type ~= "directory" then
		fail("parent is not a directory: " .. parent)
	end
end

local function atomic_write(path, data, expected_snapshot)
	path = check_target(path)
	mkdir_parent(path)
	local dir = vim.fs.dirname(path)
	local temp
	local fd
	for _ = 1, 20 do
		temp_counter = temp_counter + 1
		local nonce = tostring(uv.hrtime and uv.hrtime() or os.time()) .. "-" .. tostring(temp_counter)
		temp = vim.fs.joinpath(dir, "." .. vim.fs.basename(path) .. ".azithro-tmp-" .. nonce)
		fd = uv.fs_open(temp, "wx", 384)
		if fd then
			break
		end
	end
	if not fd then
		fail("cannot create temporary lockfile beside " .. path)
	end

	local function cleanup()
		if fd then
			pcall(uv.fs_close, fd)
			fd = nil
		end
		if temp then
			pcall(uv.fs_unlink, temp)
		end
	end

	local offset = 0
	while offset < #data do
		local called, written, write_err = pcall(uv.fs_write, fd, data:sub(offset + 1), offset)
		if not called or not written or written <= 0 then
			cleanup()
			fail("cannot write temporary lockfile for " .. path .. ": " .. tostring(called and (write_err or "short write") or written))
		end
		offset = offset + written
	end
	if uv.fs_fsync then
		pcall(uv.fs_fsync, fd)
	end
	local close_called, close_ok, close_err = pcall(uv.fs_close, fd)
	fd = nil
	if not close_called or not close_ok then
		cleanup()
		fail("cannot close temporary lockfile for " .. path .. ": " .. tostring(close_called and close_err or close_ok))
	end

	-- Compare against the decision-time snapshot just before installing. New files use
	-- a hard link so an intervening creator gets EEXIST rather than being overwritten.
	local snap_ok, current_snapshot = pcall(file_snapshot, path)
	if not snap_ok then
		cleanup()
		error(current_snapshot, 0)
	end
	if not same_snapshot(current_snapshot, expected_snapshot) then
		cleanup()
		fail("lockfile changed during operation; refusing to overwrite: " .. path)
	end
	if expected_snapshot == nil then
		if not uv.fs_link then
			cleanup()
			fail("cannot install new lockfile without no-clobber link support: " .. path)
		end
		local called, linked, link_err = pcall(uv.fs_link, temp, path)
		if not called or not linked then
			cleanup()
			if tostring(called and link_err or linked):match("EEXIST") then
				fail("lockfile appeared during operation; refusing to overwrite: " .. path)
			end
			fail("cannot exclusively install " .. path .. ": " .. tostring(called and link_err or linked))
		end
		pcall(uv.fs_unlink, temp)
		temp = nil
		return
	end

	-- Existing destinations are replaced atomically, but rename is not a CAS against
	-- native writers. Snapshot comparison catches ordinary intervening writes; stop
	-- other Neovim processes when using bang to avoid the remaining check/rename race.
	local called, renamed, rename_err = pcall(uv.fs_rename, temp, path)
	if not called or not renamed then
		cleanup()
		fail("cannot atomically replace " .. path .. ": " .. tostring(called and rename_err or renamed))
	end
	temp = nil
end

local function same_file(a, b)
	return real_path(a) == real_path(b)
end

local function set_lock(path)
	vim.o.packlockfile = path
	configured_path = path
end

local function resolve_override(opts)
	if opts.path ~= nil then
		return opts.path
	end
	return vim.env.AZITHRO_PACK_LOCK
end

local function notify(message, level)
	if vim.notify then
		vim.notify(message, level)
	end
end

local function install_commands()
	if not vim.api or not vim.api.nvim_create_user_command then
		return
	end
	vim.api.nvim_create_user_command("AzithroLockExport", function(opts)
		local ok, err = pcall(M.export, opts.fargs[1], opts.bang)
		if ok then
			notify("Azithro lock exported to " .. opts.fargs[1], vim.log.levels.INFO)
		else
			notify(tostring(err), vim.log.levels.ERROR)
		end
	end, { nargs = 1, bang = true, complete = "file", force = true, desc = "Export the active vim.pack lockfile" })
	vim.api.nvim_create_user_command("AzithroLockRefresh", function(opts)
		local ok, err = pcall(M.refresh, opts.bang)
		if not ok then
			notify(tostring(err), vim.log.levels.ERROR)
		end
	end, { nargs = 0, bang = true, force = true, desc = "Refresh the active vim.pack lockfile from the bundled lock" })
end

--- Configure Neovim's native vim.pack lockfile before any vim.pack call.
--- `opts.path`, when supplied, must be an absolute override path.
function M.setup(opts)
	opts = opts or {}
	if type(opts) ~= "table" then
		fail("setup expects an options table")
	end
	if vim.fn.exists("+packlockfile") ~= 1 then
		fail("Neovim lacks 'packlockfile' support; use a compatible pinned nightly (Neovim 0.13+)")
	end
	local override = resolve_override(opts)
	local using_override = override ~= nil and override ~= ""
	local config_path = vim.fs.normalize(vim.fs.joinpath(vim.fn.stdpath("config"), "nvim-pack-lock.json"))
	local target
	if using_override then
		target = absolute_path(override, "override path")
	else
		target = absolute_path(config_path, "config lockfile")
		if is_store_path(target) or is_store_path(real_path(target)) then
			fail("default config lockfile is in an immutable store; set AZITHRO_PACK_LOCK to an absolute writable lockfile path")
		end
	end
	check_target(target)

	local bundled_data = validated_file(bundled_lock, true, true)
	if using_override then
		local existing = validated_file(target, false)
		if not existing then
			atomic_write(target, bundled_data, nil)
		end
	else
		-- The config lock is the tracked default; never replace or seed it from the bundle.
		validated_file(target, false)
	end
	set_lock(target)
	install_commands()
	return target
end

--- Copy the active lockfile to an explicit absolute checkout filename.
function M.export(path, force)
	if not configured_path then
		fail("call setup() before export()")
	end
	local target = check_target(absolute_path(path, "export target"))
	local source_data = validated_file(configured_path, true)
	if same_file(target, configured_path) then
		return true, "source and target are the same file"
	end
	local snapshot = file_snapshot(target)
	local existing = snapshot and snapshot.data or nil
	if existing then
		validate_lock(existing, target)
	end
	if existing == source_data then
		return true, "target is already current"
	end
	if existing and not force then
		fail("export target already exists with different contents; use :AzithroLockExport! to replace it")
	end
	atomic_write(target, source_data, snapshot)
	return true
end

--- Replace the active lockfile with the bundled lock. Existing changed files need force.
function M.refresh(force)
	if not configured_path then
		fail("call setup() before refresh()")
	end
	local bundled_data = validated_file(bundled_lock, true, true)
	local target = check_target(configured_path)
	if same_file(target, bundled_lock) then
		return true, "active lock is the bundled lock"
	end
	local snapshot = file_snapshot(target)
	local existing = snapshot and snapshot.data or nil
	if existing then
		validate_lock(existing, target)
	end
	if existing == bundled_data then
		return true, "active lock is already current"
	end
	if existing and not force then
		fail("active lock differs from the bundled lock; use :AzithroLockRefresh! to replace it")
	end
	atomic_write(target, bundled_data, snapshot)
	notify("Lock refreshed. RESTART Neovim before running :ZPack restore; vim.pack caches lock data at first use.", vim.log.levels.WARN)
	return true
end

return M
