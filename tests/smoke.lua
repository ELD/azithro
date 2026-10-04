local uv = vim.uv or vim.loop

local source = debug.getinfo(1, "S").source:gsub("^@", "")
if source:sub(1, 1) ~= "/" then
	source = vim.fs.joinpath(vim.fn.getcwd(), source)
end
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
local canonical_lock = vim.fs.joinpath(root, "nvim-pack-lock.json")
local canonical_bytes
local readonly_paths = {}
local temp

local function path(...)
	return vim.fs.joinpath(temp, ...)
end

local function mkdir(dir)
	local result = vim.fn.mkdir(dir, "p")
	assert(result == 1 or uv.fs_stat(dir), "failed to create " .. dir)
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

local function write_file(filename, data, mode)
	mkdir(vim.fs.dirname(filename))
	local fd, err = uv.fs_open(filename, "w", mode or 384)
	assert(fd, err)
	local offset = 0
	while offset < #data do
		local written, write_err = uv.fs_write(fd, data:sub(offset + 1), offset)
		assert(written and written > 0, write_err or "short write")
		offset = offset + written
	end
	assert(uv.fs_close(fd))
end

local function minimal_env(home)
	return {
		PATH = vim.env.PATH or "/usr/bin:/bin",
		HOME = home,
		GIT_CONFIG_GLOBAL = "/dev/null",
		GIT_CONFIG_NOSYSTEM = "1",
		GIT_TERMINAL_PROMPT = "0",
		GIT_NO_LAZY_FETCH = "1",
		GIT_OPTIONAL_LOCKS = "0",
		GCM_INTERACTIVE = "Never",
		LANG = "C",
		LC_ALL = "C",
	}
end

local function copy_tree(from, to)
	local stat = assert(uv.fs_stat(from), "missing runtime config path: " .. from)
	if stat.type == "directory" then
		mkdir(to)
		local scan = assert(uv.fs_scandir(from))
		while true do
			local name, kind = uv.fs_scandir_next(scan)
			if not name then
				break
			end
			if name ~= ".git" and name ~= "target" then
				local child_from = vim.fs.joinpath(from, name)
				local child_stat = uv.fs_lstat(child_from)
				if child_stat and child_stat.type == "link" then
					-- Runtime config does not need symlinks; copying their targets avoids
					-- accidentally retaining a link back into the live checkout.
					local real = uv.fs_realpath(child_from)
					assert(real, "dangling symlink in runtime config: " .. child_from)
					copy_tree(real, vim.fs.joinpath(to, name))
				elseif kind == "directory" or (child_stat and child_stat.type == "directory") then
					copy_tree(child_from, vim.fs.joinpath(to, name))
				else
					local data = read_file(child_from)
					write_file(vim.fs.joinpath(to, name), data)
				end
			end
		end
	else
		write_file(to, read_file(from))
	end
end

local function make_readonly(filename)
	local stat = assert(uv.fs_stat(filename), "missing config path: " .. filename)
	readonly_paths[#readonly_paths + 1] = { path = filename, mode = stat.mode % 4096 }
	local mode = stat.type == "directory" and 365 or 292 -- 0555 / 0444
	assert(uv.fs_chmod(filename, mode))
end

local function make_tree_readonly(dir)
	local scan = assert(uv.fs_scandir(dir))
	while true do
		local name = uv.fs_scandir_next(scan)
		if not name then
			break
		end
		local child = vim.fs.joinpath(dir, name)
		local stat = assert(uv.fs_lstat(child))
		if stat.type == "directory" then
			make_tree_readonly(child)
		else
			make_readonly(child)
		end
	end
	make_readonly(dir)
end

local function restore_permissions()
	for index = #readonly_paths, 1, -1 do
		local item = readonly_paths[index]
		pcall(uv.fs_chmod, item.path, item.mode)
	end
	readonly_paths = {}
end

local function normalize_github_url(url)
	if type(url) ~= "string" then
		return nil
	end
	url = url:gsub("^git@github%.com:", "https://github.com/")
	url = url:gsub("^ssh://git@github%.com/", "https://github.com/")
	url = url:gsub("%.git$", "")
	return url
end

local function local_checkout_dirs()
	local roots, seen = {}, {}
	local function add(pathname)
		if pathname and pathname ~= "" then
			pathname = vim.fs.normalize(pathname)
			if not seen[pathname] then
				seen[pathname] = true
				roots[#roots + 1] = pathname
			end
		end
	end

	add(vim.fn.stdpath("data"))
	add(vim.fs.joinpath(vim.fn.stdpath("data"), "nvim"))
	if vim.env.XDG_DATA_HOME then
		add(vim.fs.joinpath(vim.env.XDG_DATA_HOME, "nvim"))
	end
	if vim.env.HOME and vim.env.NVIM_APPNAME then
		add(vim.fs.joinpath(vim.env.HOME, ".local", "share", vim.env.NVIM_APPNAME))
	end
	if vim.env.HOME then
		add(vim.fs.joinpath(vim.env.HOME, ".local", "share", "nvim"))
	end
	for entry in (vim.env.NVIM_TEST_PLUGIN_ROOTS or ""):gmatch("[^" .. (package.config:sub(1, 1) == "\\" and ";" or ":") .. "]+") do
		add(entry)
	end

	local checkouts, checkout_seen = {}, {}
	for _, base in ipairs(roots) do
		for _, pattern in ipairs({ "site/pack/*/*/*", "nvim/site/pack/*/*/*" }) do
			for _, candidate in ipairs(vim.fn.globpath(base, pattern, false, true)) do
				candidate = vim.fs.normalize(candidate)
				local stat = uv.fs_stat(candidate)
				if stat and stat.type == "directory" and not checkout_seen[candidate] then
					checkout_seen[candidate] = true
					checkouts[#checkouts + 1] = candidate
				end
			end
		end
	end
	return checkouts
end

local function make_git_config(lock, git_config, home)
	local empty_env = minimal_env(home)
	local candidates = {}
	for _, dir in ipairs(local_checkout_dirs()) do
		local origin_result = vim.system({ "git", "-C", dir, "remote", "get-url", "origin" }, {
			text = true,
			env = empty_env,
			clear_env = true,
		}):wait()
		if origin_result.code == 0 then
			local origin = normalize_github_url((origin_result.stdout or ""):gsub("%s+$", ""))
			if origin then
				candidates[origin] = candidates[origin] or {}
				table.insert(candidates[origin], dir)
			end
		end
	end

	local mapped = 0
	local mirrors_dir = path("git-mirrors")
	mkdir(mirrors_dir)
	for name, entry in pairs(lock.plugins) do
		local source = normalize_github_url(entry.src)
		for _, dir in ipairs(candidates[source] or {}) do
			local check = vim.system({ "git", "-C", dir, "cat-file", "-e", entry.rev .. "^{commit}" }, {
				text = true,
				env = empty_env,
				clear_env = true,
			}):wait()
			if check.code == 0 then
				-- User checkouts are often partial clones. Seed only from the exact
				-- pinned tree when every tree/blob object is already local; the no-lazy
				-- Git environment above guarantees these checks never mutate that checkout.
				local tree = vim.system({ "git", "-C", dir, "rev-list", "--objects", "--missing=print", "--no-walk", entry.rev }, {
					text = true,
					env = empty_env,
					clear_env = true,
				}):wait()
				local missing = (tree.stdout or ""):find("^%?") or (tree.stdout or ""):find("\n%?")
				local complete = tree.code == 0 and not missing
				if complete then
					local mirror = vim.fs.joinpath(mirrors_dir, name:gsub("[^%w_.%-]", "_") .. ".git")
					local initialized = vim.system({ "git", "init", "--bare", "--quiet", mirror }, {
						text = true,
						env = empty_env,
						clear_env = true,
					}):wait()
					if initialized.code == 0 then
						local fetched = vim.system({
							"git", "-C", mirror, "fetch", "--depth=1", "--no-tags", vim.uri_from_fname(dir),
							entry.rev .. ":refs/heads/azithro-pinned",
						}, {
							text = true,
							env = empty_env,
							clear_env = true,
						}):wait()
						if fetched.code == 0 then
							-- Preserve tags directly pointing at the lock commit. vim.pack
							-- needs these refs to resolve semver ranges (for example Blink's
							-- v1.10.2) before it checks out the lockfile revision.
							local source_tags = vim.system({ "git", "-C", dir, "tag", "--points-at", entry.rev }, {
								text = true,
								env = empty_env,
								clear_env = true,
							}):wait()
							local tags_ok = source_tags.code == 0
							for tag in (source_tags.stdout or ""):gmatch("[^\r\n]+") do
								local tagged = vim.system({
									"git", "-C", mirror, "update-ref", "refs/tags/" .. tag, entry.rev,
								}, {
									text = true,
									env = empty_env,
									clear_env = true,
								}):wait()
								if tagged.code ~= 0 then
									tags_ok = false
									break
								end
							end
							local head = vim.system({ "git", "-C", mirror, "symbolic-ref", "HEAD", "refs/heads/azithro-pinned" }, {
								text = true,
								env = empty_env,
								clear_env = true,
							}):wait()
							local mirrored_tree = vim.system({
								"git", "-C", mirror, "rev-list", "--objects", "--missing=print", "--no-walk", entry.rev,
							}, {
								text = true,
								env = empty_env,
								clear_env = true,
							}):wait()
							local mirror_missing = (mirrored_tree.stdout or ""):find("^%?")
								or (mirrored_tree.stdout or ""):find("\n%?")
							if tags_ok and head.code == 0 and mirrored_tree.code == 0 and not mirror_missing then
								local local_url = vim.uri_from_fname(mirror)
								local cfg = vim.system({
									"git", "config", "--file", git_config, "--add",
									"url." .. local_url .. ".insteadOf", entry.src,
								}, {
									text = true,
									env = empty_env,
									clear_env = true,
								}):wait()
								assert(cfg.code == 0, cfg.stderr or "could not configure local Git mirror for " .. name)
								mapped = mapped + 1
								break
							end
						end
					end
				end
			end
		end
	end
	return mapped
end

local function nvim_binary()
	local binary = vim.env.NVIM_TEST
	if binary == nil or binary == "" then
		binary = vim.v.progpath
	end
	assert(binary and binary ~= "" and vim.fn.executable(binary) == 1, "cannot execute Neovim binary: " .. tostring(binary))
	local result = vim.system({ binary, "--version" }, { text = true, timeout = 10000 }):wait()
	assert(result.code == 0, "cannot query Neovim version: " .. tostring(result.stderr))
	local major, minor = (result.stdout or ""):match("NVIM v?(%d+)%.(%d+)")
	major, minor = tonumber(major), tonumber(minor)
	assert(major and (major > 0 or minor >= 13),
		("Neovim %s.%s is too old (need 0.13+ for packlockfile)"):format(tostring(major), tostring(minor)))
	return binary, (result.stdout or ""):match("^[^\n]+") or "unknown version"
end

local function child_script(config_dir, state_lock, git_config, work_dir, home, report_path, mirror_count, wait_timeout_ms)
	return table.concat({
		"local config_dir = " .. string.format("%q", config_dir),
		"local state_lock = " .. string.format("%q", state_lock),
		"local git_config = " .. string.format("%q", git_config),
		"local work_dir = " .. string.format("%q", work_dir),
		"local home = " .. string.format("%q", home),
		"local report_path = " .. string.format("%q", report_path),
		"local mirror_count = " .. tostring(mirror_count),
		"local wait_timeout_ms = " .. tostring(wait_timeout_ms),
		"local expected_config = vim.fs.normalize(config_dir)",
		"local expected_data = vim.fs.normalize(vim.fs.joinpath(vim.env.XDG_DATA_HOME, 'nvim'))",
		"local expected_state = vim.fs.normalize(vim.fs.joinpath(vim.env.XDG_STATE_HOME, 'nvim'))",
		"local expected_cache = vim.fs.normalize(vim.fs.joinpath(vim.env.XDG_CACHE_HOME, 'nvim'))",
		"local uv = vim.uv or vim.loop",
		[=[
local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level, opts)
  notifications[#notifications + 1] = { message = tostring(message), level = level }
  if original_notify then
    return original_notify(message, level, opts)
  end
end

local error_echoes = {}
local original_nvim_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, history, opts)
  if opts and opts.err then
    local messages = {}
    for _, chunk in ipairs(chunks or {}) do
      messages[#messages + 1] = type(chunk) == "table" and tostring(chunk[1] or "") or tostring(chunk)
    end
    error_echoes[#error_echoes + 1] = table.concat(messages)
  end
  return original_nvim_echo(chunks, history, opts)
end

local parser_mock_calls = 0
local blink_binary_record
package.preload["tree-sitter-manager"] = function()
  return {
    setup = function(opts)
      parser_mock_calls = parser_mock_calls + 1
      assert(type(opts) == "table" and opts.auto_install == true,
        "expected the real tree-sitter-manager plugin spec to request auto_install")
      return {}
    end,
  }
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

local function write_report(report)
  local data = vim.json.encode(report) .. "\n"
  local fd, err = uv.fs_open(report_path, "w", 384)
  assert(fd, err)
  assert(uv.fs_write(fd, data, 0))
  assert(uv.fs_close(fd))
  return data
end

local function under(path, parent)
  path = vim.fs.normalize(path)
  parent = vim.fs.normalize(parent)
  return path == parent or path:sub(1, #parent + 1) == parent .. "/"
end

local function pack_by_name()
  local result = {}
  for _, pack in ipairs(vim.pack.get()) do
    if pack.spec and pack.spec.name then
      result[pack.spec.name] = pack
    end
  end
  return result
end

local function all_locked_packs_ready(lock)
  local installed = pack_by_name()
  for name, entry in pairs(lock.plugins) do
    local pack = installed[name]
    if not pack or pack.rev ~= entry.rev then
      return false
    end
  end
  return true
end

local function shared_libraries(pack_name)
  local pack = vim.pack.get({ pack_name })[1]
  if not pack then
    return {}
  end
  local found = {}
  local function walk(dir, depth)
    if depth > 5 then return end
    local scan = uv.fs_scandir(dir)
    if not scan then return end
    while true do
      local name, kind = uv.fs_scandir_next(scan)
      if not name then break end
      local child = vim.fs.joinpath(dir, name)
      local stat = uv.fs_lstat(child)
      if stat and stat.type == "directory" then
        walk(child, depth + 1)
      elseif name:match("%.so([%.%w_%-]*)$") or name:match("%.dylib([%.%w_%-]*)$")
          or name:match("%.dll([%.%w_%-]*)$") or name:match("%.bundle([%.%w_%-]*)$") then
        found[#found + 1] = child
      end
    end
  end
  walk(pack.path, 0)
  table.sort(found)
  return found
end

local function matching_loaded_modules()
  local found = {}
  for name, value in pairs(package.loaded) do
    local module_name = type(name) == "string" and name:lower() or ""
    if value ~= nil and (module_name:match("^blink[%.%_]") or module_name:match("^blink%-")) then
      found[#found + 1] = name
    end
  end
  table.sort(found)
  return found
end

local function run_assertions()
  assert(vim.env.AZITHRO_TOOL_PROVIDER == "nix", "smoke must use the Nix tool provider")
  assert(vim.env.AZITHRO_EXPERIMENTAL_UI == "0", "headless smoke must disable UI2")
  assert(vim.env.AZITHRO_PACK_LOCK == state_lock, "smoke lock override does not point to temporary state")
  assert(vim.env.GIT_CONFIG_GLOBAL == git_config, "Git global config is not isolated")
  assert(vim.env.GIT_DIR == nil and vim.env.GIT_WORK_TREE == nil,
    "Git repository override variables leaked into the smoke child")
  assert(uv.fs_realpath(vim.env.HOME) == uv.fs_realpath(home), "HOME is not temporary")
  local temp_root = vim.fs.dirname(work_dir)
  for _, isolated_path in ipairs({
    vim.env.XDG_CONFIG_HOME, vim.env.XDG_DATA_HOME, vim.env.XDG_STATE_HOME, vim.env.XDG_CACHE_HOME,
    vim.env.XDG_CONFIG_DIRS, vim.env.XDG_DATA_DIRS, vim.env.TMPDIR, vim.env.GIT_CONFIG_GLOBAL,
  }) do
    assert(isolated_path and under(isolated_path, temp_root), "an XDG/TMP/Git path escaped the temporary tree: " .. tostring(isolated_path))
  end
  assert(uv.fs_realpath(vim.fn.getcwd()) == uv.fs_realpath(work_dir), "child cwd is not temporary")
  assert(vim.fs.normalize(vim.fn.stdpath("config")) == expected_config, "config stdpath is not temporary")
  assert(vim.fs.normalize(vim.fn.stdpath("data")) == expected_data, "data stdpath is not temporary")
  assert(vim.fs.normalize(vim.fn.stdpath("state")) == expected_state, "state stdpath is not temporary")
  assert(vim.fs.normalize(vim.fn.stdpath("cache")) == expected_cache, "cache stdpath is not temporary")
  assert(under(state_lock, expected_state), "native lock is outside isolated XDG state")
  assert(vim.o.packlockfile == state_lock, "Neovim native packlockfile was not redirected")
  local bundled_lock_path = vim.fs.joinpath(expected_config, "nvim-pack-lock.json")
  assert(read_file(bundled_lock_path) ~= "", "read-only copied bundle lock is missing")
  assert((assert(uv.fs_stat(bundled_lock_path)).mode % 512) == 292, "copied bundled lock is not chmod read-only")
  assert((assert(uv.fs_stat(expected_config)).mode % 512) == 365, "copied config directory is not chmod read-only")

  local lock = vim.json.decode(read_file(vim.fs.joinpath(expected_config, "nvim-pack-lock.json")))
  assert(type(lock) == "table" and type(lock.plugins) == "table", "copied plugin lock is invalid")
  for name, entry in pairs(lock.plugins) do
    assert(type(entry.rev) == "string" and #entry.rev == 40, "invalid pinned Git commit for " .. name)
    assert(type(entry.src) == "string" and entry.src:match("^https://github%.com/"), "invalid source URL for " .. name)
  end

  -- Headless Neovim has no UIEnter, and some ZPack event specs depend on it.
  vim.api.nvim_exec_autocmds("UIEnter", { modeline = false })
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })

  local started = vim.uv.hrtime()
  local ready = vim.wait(wait_timeout_ms, function()
    return all_locked_packs_ready(lock)
  end, 100)
  assert(ready, "timed out waiting for fresh vim.pack installations at bundled revisions")

  local installed = pack_by_name()
  local data_root = vim.fs.normalize(expected_data) .. "/"
  local installed_count = 0
  for name, entry in pairs(lock.plugins) do
    local pack = assert(installed[name], "missing fresh native vim.pack install: " .. name)
    assert(pack.rev == entry.rev, ("%s installed at %s, expected locked commit %s"):format(name, tostring(pack.rev), entry.rev))
    assert(under(pack.path, expected_data), "plugin escaped isolated data directory: " .. pack.path)
    assert(pack.path:sub(1, #data_root) == data_root, "plugin path is not under isolated XDG data: " .. pack.path)
    installed_count = installed_count + 1
  end
  assert(installed_count > 0, "no locked plugins were installed")
  assert(uv.fs_stat(state_lock), "config.pack did not create the temporary native lock")
  local native_lock = vim.json.decode(read_file(state_lock))
  assert(type(native_lock.plugins) == "table", "native state lock is invalid")
  for name, entry in pairs(lock.plugins) do
    if native_lock.plugins[name] then
      assert(native_lock.plugins[name].rev == entry.rev, "native lock revision changed for " .. name)
    end
  end

  -- Load lazy, real plugin modules and their real config functions. The sole
  -- preload above is the parser installer, to keep grammar downloads out of smoke.
  local neotest = require("neotest")
  assert(type(neotest) == "table" and type(neotest.run) == "table", "real Neotest did not load")
  local dap = require("dap")
  assert(type(dap) == "table" and type(dap.adapters) == "table", "real nvim-dap did not load")
  assert(type(dap.adapters["pwa-node"]) == "function", "Nix JavaScript debug adapter was not configured")
  assert(type(dap.adapters.codelldb) == "function", "Nix CodeLLDB debug adapter was not configured")
  assert(dap.configurations.typescript and dap.configurations.typescript[1].type == "pwa-node",
    "TypeScript DAP launch config is missing")
  assert(dap.configurations.rust and dap.configurations.rust[1].type == "codelldb",
    "Rust DAP launch config is missing")

  local typescript = require("plugins.typescript")
  local preferences = typescript.opts.settings.tsserver_file_preferences
  assert(preferences.includeCompletionsForImportStatements == true)
  assert(preferences.includeCompletionsForModuleExports == true)
  assert(preferences.quotePreference == "auto")
  assert(preferences.allowIncompleteCompletions == false)
  assert(preferences.allowRenameOfImportPath == true)

  local conform = require("conform")
  assert(type(conform) == "table" and type(conform.format) == "function", "real Conform module is unavailable")
  assert(type(conform.list_formatters) == "function", "Conform API did not initialize")

  assert(package.loaded.mason == nil and package.loaded["mason-registry"] == nil,
    "Mason was loaded with AZITHRO_TOOL_PROVIDER=nix")
  for name in pairs(package.loaded) do
    assert(type(name) ~= "string" or not name:match("^mason[%._%-]"), "Mason module was loaded: " .. name)
  end

  local blink_pack = vim.pack.get({ "blink.cmp" })[1]
  local blink_module_file = blink_pack and vim.fs.joinpath(blink_pack.path, "lua", "blink", "cmp", "init.lua")
  blink_binary_record = {
    blink_cmp_shared_libraries = shared_libraries("blink.cmp"),
    blink_pairs_shared_libraries = shared_libraries("blink.pairs"),
    loaded_blink_modules = matching_loaded_modules(),
    blink_cmp_module_files = vim.api.nvim_get_runtime_file("lua/blink/cmp/init.lua", false),
    blink_cmp_module_file_exists = blink_module_file ~= nil and uv.fs_stat(blink_module_file) ~= nil,
    blink_cmp_root_entries = blink_pack and vim.fn.readdir(blink_pack.path) or {},
    blink_cmp_lua_entries = blink_pack and vim.fn.readdir(vim.fs.joinpath(blink_pack.path, "lua")) or {},
    blink_cmp_native_path = blink_pack and blink_pack.path or "missing",
    note = "Blink Pairs native availability and parser matching are asserted; artifact inventory is diagnostic, not a benchmark.",
  }
  local blink_info = require("zpack.api").get_plugin("blink.cmp")
  blink_binary_record.blink_cmp_native_active = blink_pack and blink_pack.active or false
  blink_binary_record.blink_cmp_zpack_status = blink_info and blink_info.status or "missing"
  blink_binary_record.blink_cmp_native_path = blink_pack and blink_pack.path or "missing"
  assert(blink_pack and blink_pack.active and blink_info and blink_info.status == "loaded",
    "ZPack did not activate blink.cmp: native=" .. vim.inspect(blink_pack) .. ", zpack=" .. vim.inspect(blink_info))
  assert(vim.tbl_contains(vim.api.nvim_list_runtime_paths(), blink_pack.path),
    "blink.cmp is marked active but absent from runtimepath: " .. blink_pack.path)
  local blink_cmp = require("blink.cmp")
  assert(type(blink_cmp) == "table" and type(blink_cmp.setup) == "function", "real blink.cmp did not load")
  assert(type(blink_cmp.get_lsp_capabilities) == "function", "blink.cmp public LSP capability API is missing")
  assert(type(blink_cmp.get_lsp_capabilities()) == "table", "blink.cmp capability API did not execute")
  local markview_info = require("zpack.api").get_plugin("markview.nvim")
  assert(markview_info and markview_info.status == "loaded", "Markview did not load at startup")
  for _, command in ipairs({ "Markview", "Editor", "Heading", "Checkbox" }) do
    assert(vim.fn.exists(":" .. command) == 2, "Missing Markview command: " .. command)
  end
  local blink_sources = require("blink.cmp.config").sources
  assert(vim.g.markview_blink_loaded == true, "Markview Blink integration did not register")
  assert(blink_sources.providers.markview.module == "blink-markview", "Missing Markview completion provider")
  assert(vim.tbl_contains(blink_sources.per_filetype.markdown, "markview"), "Markdown lacks Markview completions")
  assert(vim.tbl_contains(blink_sources.per_filetype.markdown, "lsp"), "Markview replaced existing Blink sources")
  local markdown_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(markdown_buf)
  vim.bo[markdown_buf].filetype = "markdown"
  assert(vim.fn.maparg("<leader>me", "n", false, true).buffer == 1, "Markview extra mapping is not buffer-local")
  assert(require("markview.spec").get({ "preview", "map_gx" }, { ignore_enable = true }) == false,
    "Markview must preserve gx")
  vim.api.nvim_buf_delete(markdown_buf, { force = true })

  local blink_pairs = require("blink.pairs")
  assert(type(blink_pairs) == "table", "real blink.pairs did not load")
  assert(type(blink_pairs.library_available) == "function", "blink.pairs native-library API is missing")
  blink_binary_record.blink_pairs_library_available = blink_pairs.library_available()
  assert(blink_binary_record.blink_pairs_library_available == true,
    "blink.pairs native library is unavailable after config/build hooks and download")
  blink_binary_record.blink_pairs_shared_libraries = shared_libraries("blink.pairs")

  local blink_pairs_parser = require("blink.pairs.rust")
  assert(type(blink_pairs_parser.parse_buffer) == "function", "blink.pairs Rust parser API did not load")
  assert(type(blink_pairs_parser.get_match_pair) == "function", "blink.pairs native match-pair API is missing")
  local parser_bufnr = 987654321
  local supported, first_line, last_line = blink_pairs_parser.parse_buffer(parser_bufnr, 8, "lua", "(x)")
  assert(supported and first_line == 0 and last_line >= 1,
    "blink.pairs native parser did not parse the Lua fixture")
  local native_pair = blink_pairs_parser.get_match_pair(parser_bufnr, 0, 0)
  assert(native_pair and native_pair[1] and native_pair[2], "blink.pairs native parser found no matching delimiter pair")
  assert(native_pair[1][1] == "(" and native_pair[1][2] == ")" and native_pair[1].col == 0,
    "blink.pairs native parser returned an invalid opening delimiter match")
  assert(native_pair[2][1] == "(" and native_pair[2][2] == ")" and native_pair[2].col == 2,
    "blink.pairs native parser returned an invalid closing delimiter match")
  blink_pairs_parser.remove_buffer(parser_bufnr)
  blink_binary_record.blink_pairs_native_match = { opening_col = native_pair[1].col, closing_col = native_pair[2].col }

  local binary_record = blink_binary_record
  assert(parser_mock_calls > 0, "the parser manager config did not use the explicit smoke-only mock")

  -- Give scheduled config callbacks one turn to report any ZPack/plugin errors.
  vim.wait(300, function() return false end, 25)
  local errors = {}
  for _, notice in ipairs(notifications) do
    if notice.level == vim.log.levels.ERROR then
      errors[#errors + 1] = notice.message
    end
  end
  assert(#errors == 0, "ZPack/plugin configuration emitted ERROR notification(s):\n" .. table.concat(errors, "\n"))
  assert(#error_echoes == 0, "ZPack/plugin configuration emitted nvim_echo ERROR(s):\n" .. table.concat(error_echoes, "\n"))

  local report = {
    status = "passed",
    neovim = vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
    local_git_mirrors = mirror_count,
    installed_locked_plugins = installed_count,
    install_and_configure_ms = math.floor((uv.hrtime() - started) / 1000000),
    parser_manager_mock_calls = parser_mock_calls,
    parser_runtime_validation = false,
    blink_native = binary_record,
    error_notifications = errors,
    error_echoes = error_echoes,
  }
  write_report(report)
  print("tests/smoke.lua: native ZPack/vim.pack integration passed")
  print(("Neovim %s; %d fresh locked plugins; %d local Git mirrors"):format(report.neovim, installed_count, mirror_count))
  print("Blink Pairs native delimiter matching passed; parser installation intentionally mocked")
end

local function finish()
  local ok, err = xpcall(run_assertions, debug.traceback)
  if not ok then
    local errors = {}
    for _, notice in ipairs(notifications) do
      if notice.level == vim.log.levels.ERROR then errors[#errors + 1] = notice.message end
    end
    local report = {
      status = "failed",
      error = tostring(err):match("^[^\n]+"),
      error_notifications = errors,
      error_echoes = error_echoes,
      parser_manager_mock_calls = parser_mock_calls,
      parser_runtime_validation = false,
      blink_native = blink_binary_record,
      local_git_mirrors = mirror_count,
    }
    pcall(write_report, report)
    io.stderr:write("tests/smoke.lua: " .. tostring(err) .. "\n")
    vim.cmd("cquit 1")
    return
  end
  vim.cmd("qa!")
end

vim.opt.rtp:prepend(config_dir)
local init_ok, init_err = xpcall(function()
  dofile(vim.fs.joinpath(config_dir, "init.lua"))
end, debug.traceback)
if not init_ok then
  pcall(write_report, { status = "failed", error = tostring(init_err):match("^[^\n]+"), error_notifications = notifications,
    error_echoes = error_echoes, parser_manager_mock_calls = parser_mock_calls, parser_runtime_validation = false,
    local_git_mirrors = mirror_count })
  io.stderr:write("Azithro init failed: " .. tostring(init_err) .. "\n")
  vim.cmd("cquit 1")
  return
end
vim.schedule(finish)
]=],
	}, "\n")
end

local function run()
	assert(vim.fn.executable("git") == 1, "git is required")
	local binary, version = nvim_binary()
	canonical_bytes = read_file(canonical_lock)
	local lock = vim.json.decode(canonical_bytes)
	assert(type(lock.plugins) == "table", "canonical lock has no plugins object")

	local temp_parent = uv.fs_stat("/tmp") and "/tmp" or uv.os_tmpdir()
	temp = assert(uv.fs_mkdtemp(vim.fs.joinpath(temp_parent, "azsmoke-XXXXXX")))
	local home = path("home")
	local xdg_config = path("xdg-config")
	local config_dir = vim.fs.joinpath(xdg_config, "nvim")
	local data_home = path("xdg-data")
	local state_home = path("xdg-state")
	local cache_home = path("xdg-cache")
	local work_dir = path("work")
	local xdg_config_dirs = path("xdg-config-dirs")
	local xdg_data_dirs = path("xdg-data-dirs")
	local git_config = path("gitconfig")
	local state_lock = vim.fs.joinpath(state_home, "nvim", "azithro-pack-lock.json")
	local report_path = path("report.json")
	local driver_path = path("smoke-driver.lua")
	local launcher_path = path("run-nvim.sh")
	local child_log_path = path("child.log")
	for _, dir in ipairs({ home, xdg_config, data_home, state_home, cache_home, work_dir, xdg_config_dirs, xdg_data_dirs }) do
		mkdir(dir)
	end

	for _, entry in ipairs({ "init.lua", "nvim-pack-lock.json", "lua", "after" }) do
		local from = vim.fs.joinpath(root, entry)
		if uv.fs_lstat(from) then
			copy_tree(from, vim.fs.joinpath(config_dir, entry))
		end
	end
	make_tree_readonly(config_dir)
	write_file(git_config, "")
	local mirror_count = make_git_config(lock, git_config, home)
	assert(uv.fs_chmod(git_config, 292)) -- 0444

	local timeout_ms = tonumber(vim.env.NVIM_TEST_TIMEOUT_MS) or 15 * 60 * 1000
	assert(timeout_ms >= 10000, "NVIM_TEST_TIMEOUT_MS must be at least 10000ms")
	local child_timeout_ms = math.max(5000, timeout_ms - 5000)
	local driver = child_script(config_dir, state_lock, git_config, work_dir, home, report_path, mirror_count, child_timeout_ms)
	write_file(driver_path, driver)
	write_file(launcher_path, '#!/bin/sh\noutput=$1\nshift\nexec "$@" >"$output" 2>&1\n', 448) -- 0700

	local child_env = {
		PATH = vim.env.PATH or "/usr/bin:/bin",
		HOME = home,
		XDG_CONFIG_HOME = xdg_config,
		XDG_DATA_HOME = data_home,
		XDG_STATE_HOME = state_home,
		XDG_CACHE_HOME = cache_home,
		XDG_CONFIG_DIRS = xdg_config_dirs,
		XDG_DATA_DIRS = xdg_data_dirs,
		TMPDIR = temp,
		NVIM_APPNAME = nil,
		GIT_CONFIG_GLOBAL = git_config,
		GIT_CONFIG_NOSYSTEM = "1",
		GIT_TERMINAL_PROMPT = "0",
		-- Network partial clones need lazy blob fetching to materialize their checkout.
		-- Only read-only inspection of existing user checkouts disables lazy fetch.
		GIT_OPTIONAL_LOCKS = "0",
		GCM_INTERACTIVE = "Never",
		LANG = "C",
		LC_ALL = "C",
		AZITHRO_TOOL_PROVIDER = "nix",
		AZITHRO_EXPERIMENTAL_UI = "0",
		AZITHRO_PACK_LOCK = state_lock,
	}
	if vim.env.AZITHRO_SMOKE_GIT_TRACE == "1" then
		child_env.GIT_TRACE2_EVENT = path("git-trace2.json")
		child_env.GIT_TRACE = path("git-trace.log")
	end
	mkdir(child_env.TMPDIR)

	local shell = vim.fn.exepath("sh")
	assert(shell ~= "", "sh is required to safely capture the child Neovim output")
	local result = vim.system({ shell, launcher_path, child_log_path, binary, "--headless", "-i", "NONE", "-u", driver_path }, {
		cwd = work_dir,
		text = true,
		env = child_env,
		clear_env = true,
		timeout = timeout_ms,
	}):wait()
	local report = uv.fs_stat(report_path) and read_file(report_path) or "(child did not write a smoke report)"
	local child_output = uv.fs_stat(child_log_path) and read_file(child_log_path) or "(child output log missing)"
	assert(read_file(canonical_lock) == canonical_bytes, "smoke modified the canonical bundled lock")
	assert(read_file(vim.fs.joinpath(config_dir, "nvim-pack-lock.json")) == canonical_bytes,
		"smoke modified the copied, read-only bundled lock")
	assert(result.code == 0, table.concat({
		"full-plugin smoke failed using " .. version .. " (exit " .. tostring(result.code) .. ")",
		"child output (last 2500 bytes):\n" .. child_output:sub(-2500),
		"child report: " .. report:sub(1, 2500),
	}, "\n"))
	assert(report:find('"status":"passed"', 1, true), "child did not report smoke success:\n" .. report)
	local summary = vim.json.decode(report)
	print(("tests/smoke.lua: passed (Neovim %s; %d pinned plugins; native Blink Pairs; parsers mocked)")
		:format(summary.neovim, summary.installed_locked_plugins))
end

local ok, err = xpcall(run, debug.traceback)
restore_permissions()
if temp then
	if vim.env.AZITHRO_SMOKE_KEEP_TEMP == "1" then
		io.stderr:write("smoke temp retained: " .. temp .. "\n")
	else
		pcall(vim.fn.delete, temp, "rf")
	end
end
if not ok then
	error(err, 0)
end
