local source = debug.getinfo(1, "S").source:gsub("^@", "")
if source:sub(1, 1) ~= "/" then
  source = vim.fs.joinpath(vim.fn.getcwd(), source)
end
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
local original_package_path = package.path
package.path = table.concat({ root .. "/lua/?.lua", root .. "/lua/?/init.lua", package.path }, ";")

local env_names = {
  "AZITHRO_TOOL_PROVIDER",
  "AZITHRO_PACK_LOCK",
  "AZITHRO_STITCHR_PATH",
  "AZITHRO_EXPERIMENTAL_UI",
  "AZITHRO_PROFILING",
  "AZITHRO_AI_ENABLED",
  "AZITHRO_AI_MODEL",
}
local original_env = {}
for _, name in ipairs(env_names) do
  original_env[name] = vim.env[name]
end

local module_names = {
  "config.runtime",
  "config.pack",
  "config.lsp",
  "vim._core.ui2",
  "mason-lspconfig",
  "lint",
  "99",
  "tree-sitter-manager",
  "plugins.typescript",
  "plugins.lint",
  "plugins.lsp.mason-lspconfig",
  "plugins.mason-tools",
  "plugins.tiny-cmdline",
  "plugins.99",
  "plugins.treesitter-manager",
}
local original_modules = {}
for _, name in ipairs(module_names) do
  original_modules[name] = { value = package.loaded[name] }
end
local preload_names = { "vim._core.ui2", "mason-lspconfig", "99" }
local original_preloads = {}
for _, name in ipairs(preload_names) do
  original_preloads[name] = { value = package.preload[name] }
end

local original_vim = {
  schedule = vim.schedule,
  notify = vim.notify,
  api_create_augroup = vim.api.nvim_create_augroup,
  api_create_autocmd = vim.api.nvim_create_autocmd,
  lsp_config = vim.lsp.config,
  lsp_enable = vim.lsp.enable,
  treesitter_register = vim.treesitter.language.register,
  filetype_add = vim.filetype.add,
  fn_isdirectory = vim.fn.isdirectory,
  fn_filereadable = vim.fn.filereadable,
  keymap_set = vim.keymap.set,
}

local function clear_env()
  for _, name in ipairs(env_names) do
    vim.env[name] = nil
  end
end

local function load_runtime(values)
  clear_env()
  for name, value in pairs(values or {}) do
    vim.env[name] = value
  end
  package.loaded["config.runtime"] = nil
  return require("config.runtime")
end

local function fresh_plugin(name, runtime)
  package.loaded["config.runtime"] = runtime
  package.loaded[name] = nil
  return require(name)
end

local function contains(values, wanted)
  for _, value in ipairs(values or {}) do
    if value == wanted then
      return true
    end
  end
  return false
end

local function run()
  -- Defaults and explicit environment values.
  local runtime = load_runtime({})
  assert(runtime.tool_provider == "mason", "tool_provider must default to Mason")
  assert(runtime.pack_lock == nil and runtime.stitchr_path == nil, "optional paths must default to nil")
  assert(runtime.experimental_ui == true, "experimental UI must default on")
  assert(runtime.profiling == false, "profiling must default off")
  assert(runtime.ai_enabled == false and runtime.ai_model == nil, "AI must default off with no model")
  assert(runtime.ui2_enabled == false, "UI2 starts disabled")

  runtime = load_runtime({
    AZITHRO_TOOL_PROVIDER = "nix",
    AZITHRO_PACK_LOCK = "/tmp/azithro-pack-lock.json",
    AZITHRO_STITCHR_PATH = "/tmp/stitchr",
    AZITHRO_EXPERIMENTAL_UI = "false",
    AZITHRO_PROFILING = "true",
    AZITHRO_AI_ENABLED = "1",
    AZITHRO_AI_MODEL = "test-model",
  })
  assert(runtime.tool_provider == "nix")
  assert(runtime.pack_lock == "/tmp/azithro-pack-lock.json")
  assert(runtime.stitchr_path == "/tmp/stitchr")
  assert(runtime.experimental_ui == false and runtime.profiling == true)
  assert(runtime.ai_enabled == true and runtime.ai_model == "test-model")

  local invalid_settings = {
    { AZITHRO_TOOL_PROVIDER = "other", message = "AZITHRO_TOOL_PROVIDER" },
    { AZITHRO_EXPERIMENTAL_UI = "yes", message = "AZITHRO_EXPERIMENTAL_UI" },
    { AZITHRO_PROFILING = "on", message = "AZITHRO_PROFILING" },
    { AZITHRO_AI_ENABLED = "enabled", message = "AZITHRO_AI_ENABLED" },
    { AZITHRO_PACK_LOCK = "relative/lock.json", message = "AZITHRO_PACK_LOCK" },
    { AZITHRO_STITCHR_PATH = "relative/stitchr", message = "AZITHRO_STITCHR_PATH" },
  }
  for _, case in ipairs(invalid_settings) do
    local values = {}
    for name, value in pairs(case) do
      if name:match("^AZITHRO_") then
        values[name] = value
      end
    end
    local ok, err = pcall(load_runtime, values)
    assert(not ok, "invalid runtime setting was accepted")
    assert(tostring(err):find(case.message, 1, true), "unexpected validation error: " .. tostring(err))
  end

  -- The pack lock is configured before attempting to enable the experimental UI.
  local setup_events = {}
  package.loaded["config.pack"] = {
    setup = function(opts)
      setup_events[#setup_events + 1] = "pack"
      assert(opts.path == "/tmp/runtime-lock.json")
    end,
  }
  package.loaded["vim._core.ui2"] = {
    enable = function()
      setup_events[#setup_events + 1] = "ui2"
    end,
  }
  runtime = load_runtime({ AZITHRO_PACK_LOCK = "/tmp/runtime-lock.json" })
  runtime.setup()
  assert(setup_events[1] == "pack" and setup_events[2] == "ui2" and #setup_events == 2,
    "runtime setup must initialize the pack manager before UI2")
  assert(runtime.ui2_enabled == true, "successful UI2 enablement was not recorded")

  local scheduled, notices = {}, {}
  vim.schedule = function(callback)
    scheduled[#scheduled + 1] = callback
  end
  vim.notify = function(message, level)
    notices[#notices + 1] = { message = tostring(message), level = level }
  end
  local function flush_notice()
    assert(#scheduled == 1, "expected one scheduled UI fallback notice")
    scheduled[1]()
    scheduled = {}
    assert(#notices == 1 and notices[1].message:find("experimental UI unavailable", 1, true),
      "missing UI API must report the native UI fallback")
    notices = {}
  end

  -- Missing module, missing enable method, and a throwing enable method all fall back.
  package.loaded["config.pack"] = {
    setup = function() setup_events[#setup_events + 1] = "pack" end,
  }
  package.loaded["vim._core.ui2"] = nil
  package.preload["vim._core.ui2"] = function()
    error("mock private UI module unavailable")
  end
  runtime = load_runtime({})
  runtime.setup()
  assert(runtime.ui2_enabled == false)
  flush_notice()

  package.preload["vim._core.ui2"] = nil
  package.loaded["vim._core.ui2"] = {}
  runtime = load_runtime({})
  runtime.setup()
  assert(runtime.ui2_enabled == false, "UI2 without enable() must stay disabled")
  flush_notice()

  local disabled_ui = false
  package.loaded["vim._core.ui2"] = {
    enable = function() error("mock enable failure") end,
    disable = function() disabled_ui = true end,
  }
  runtime = load_runtime({})
  runtime.setup()
  assert(runtime.ui2_enabled == false and disabled_ui, "failed UI2 enablement should be cleaned up")
  flush_notice()

  -- Opting out still initializes the pack manager, but never loads UI2 or warns.
  local ui_loads = 0
  package.loaded["vim._core.ui2"] = nil
  package.preload["vim._core.ui2"] = function()
    ui_loads = ui_loads + 1
    error("opt-out must not load UI2")
  end
  runtime = load_runtime({ AZITHRO_EXPERIMENTAL_UI = "0" })
  local packs_before = #setup_events
  runtime.setup()
  assert(#setup_events == packs_before + 1 and setup_events[#setup_events] == "pack")
  assert(ui_loads == 0 and runtime.ui2_enabled == false)
  assert(#scheduled == 0 and #notices == 0, "opt-out must not schedule a fallback warning")

  -- TypeScript's real plugin spec preserves the intended tsserver preferences.
  local typescript = fresh_plugin("plugins.typescript", {})
  local preferences = typescript.opts.settings.tsserver_file_preferences
  assert(preferences.includeCompletionsForImportStatements == true)
  assert(preferences.includeCompletionsForModuleExports == true)
  assert(preferences.quotePreference == "auto")
  assert(preferences.allowIncompleteCompletions == false)
  assert(preferences.allowRenameOfImportPath == true)

  -- Exercise the actual lint plugin config with a mocked nvim-lint module.
  local lint_module = { linters_by_ft = {} }
  package.loaded.lint = lint_module
  local autocmd
  vim.api.nvim_create_augroup = function(name, opts)
    assert(name == "azithro_lint" and opts.clear == true)
    return 71
  end
  vim.api.nvim_create_autocmd = function(event, opts)
    autocmd = { event = event, opts = opts }
  end
  local lint_spec = fresh_plugin("plugins.lint", {})
  lint_spec.config()
  assert(lint_module.linters_by_ft.dockerfile[1] == "hadolint")
  assert(lint_module.linters_by_ft.markdown[1] == "markdownlint-cli2")
  assert(lint_module.linters_by_ft.sh[1] == "shellcheck")
  for ft, linters in pairs(lint_module.linters_by_ft) do
    assert(ft ~= "javascript" and ft ~= "typescript", "ESLint must not be configured as a linter")
    assert(not contains(linters, "eslint"), "ESLint must not be configured as a linter")
  end
  assert(autocmd.event == "BufWritePost" and autocmd.opts.group == 71)

  -- Nix directly enables the available LSP configs, without Mason-only servers.
  local enabled_servers, lsp_configs, enable_calls = nil, {}, 0
  vim.lsp.config = function(name, opts)
    lsp_configs[#lsp_configs + 1] = { name = name, opts = opts }
  end
  vim.lsp.enable = function(servers)
    enable_calls = enable_calls + 1
    enabled_servers = servers
  end
  package.loaded["config.lsp"] = {}
  local nix_lsp = fresh_plugin("plugins.lsp.mason-lspconfig", { tool_provider = "nix" })
  assert(nix_lsp[1] == "neovim/nvim-lspconfig")
  nix_lsp.config()
  assert(type(enabled_servers) == "table" and contains(enabled_servers, "eslint"))
  assert(not contains(enabled_servers, "rust_analyzer"), "Nix LSP list must not include rust_analyzer")
  assert(not contains(enabled_servers, "ts_ls"), "Nix LSP list must not include ts_ls")
  assert(enable_calls == 1, "Nix mode should call vim.lsp.enable exactly once")
  assert(#lsp_configs == 0, "mocked config module should not be replaced")

  -- Mason mode keeps its ensure list and automatic-enable exclusions.
  local mason_opts = nil
  enabled_servers = nil
  package.loaded["mason-lspconfig"] = {
    setup = function(opts) mason_opts = opts end,
  }
  local mason_lsp = fresh_plugin("plugins.lsp.mason-lspconfig", { tool_provider = "mason" })
  assert(mason_lsp[1] == "mason-org/mason-lspconfig.nvim")
  mason_lsp.config(mason_lsp, mason_lsp.opts)
  assert(mason_opts == mason_lsp.opts)
  assert(contains(mason_opts.automatic_enable.exclude, "rust_analyzer"))
  assert(contains(mason_opts.automatic_enable.exclude, "ts_ls"))
  assert(contains(mason_opts.ensure_installed, "rust_analyzer"))
  assert(contains(mason_opts.ensure_installed, "ts_ls"))
  assert(enable_calls == 1 and enabled_servers == nil, "Mason mode must not use direct vim.lsp.enable")

  local mason_tools = fresh_plugin("plugins.mason-tools", { tool_provider = "nix" })
  assert(mason_tools.enabled == false, "Mason tool installer must be disabled in Nix mode")
  mason_tools = fresh_plugin("plugins.mason-tools", { tool_provider = "mason" })
  assert(mason_tools.enabled == true, "Mason tool installer should stay enabled in Mason mode")

  local tiny_cmdline = fresh_plugin("plugins.tiny-cmdline", { ui2_enabled = false })
  assert(tiny_cmdline.enabled == false, "tiny-cmdline must be disabled without UI2")
  tiny_cmdline = fresh_plugin("plugins.tiny-cmdline", { ui2_enabled = true })
  assert(tiny_cmdline.enabled == true, "tiny-cmdline should enable with UI2")

  -- AI remains opt-in; an explicit model is passed through only when enabled.
  local ai_spec = fresh_plugin("plugins.99", { ai_enabled = false, ai_model = nil })
  assert(ai_spec.enabled == false, "AI plugin must default disabled")
  local ai_setup, mapped = nil, 0
  local ai = {
    Providers = { OpencodeProvider = "mock-opencode" },
    setup = function(opts) ai_setup = opts end,
    visual = function() end,
    stop_all_requests = function() end,
    search = function() end,
  }
  package.loaded["99"] = ai
  vim.keymap.set = function() mapped = mapped + 1 end
  ai_spec = fresh_plugin("plugins.99", { ai_enabled = true, ai_model = "mock-model" })
  assert(ai_spec.enabled == true, "AI plugin should enable when opted in")
  ai_spec.config()
  assert(ai_setup.provider == "mock-opencode" and ai_setup.model == "mock-model")
  assert(mapped == 3, "AI config should install its three optional keymaps")

  -- Stitchr remains optional: a missing checkout warns; a valid grammar is registered.
  local manager_opts, registrations, filetype_extensions, tree_notices = nil, {}, {}, {}
  package.loaded["tree-sitter-manager"] = {
    setup = function(opts) manager_opts = opts end,
  }
  vim.treesitter.language.register = function(language, filetype)
    registrations[#registrations + 1] = { language = language, filetype = filetype }
  end
  vim.filetype.add = function(opts) filetype_extensions[#filetype_extensions + 1] = opts end
  vim.fn.isdirectory = function(path)
    return path == "/tmp/stitchr-present" and 1 or 0
  end
  vim.fn.filereadable = function(path)
    return path == "/tmp/stitchr-present/grammar.js" and 1 or 0
  end
  vim.notify = function(message, level)
    tree_notices[#tree_notices + 1] = { message = tostring(message), level = level }
  end

  local treesitter = fresh_plugin("plugins.treesitter-manager", { stitchr_path = nil })
  treesitter.config()
  assert(manager_opts.languages.stitchr == nil and #tree_notices == 0,
    "an unset Stitchr path should leave the grammar optional")

  treesitter = fresh_plugin("plugins.treesitter-manager", { stitchr_path = "/tmp/stitchr-missing" })
  treesitter.config()
  assert(manager_opts.languages.stitchr == nil)
  assert(#tree_notices == 1 and tree_notices[1].message:find("Stitchr grammar checkout not found", 1, true))

  tree_notices, registrations, filetype_extensions = {}, {}, {}
  treesitter = fresh_plugin("plugins.treesitter-manager", { stitchr_path = "/tmp/stitchr-present" })
  treesitter.config()
  local stitchr = assert(manager_opts.languages.stitchr, "valid Stitchr grammar was not installed")
  assert(stitchr.install_info.url == "file:///tmp/stitchr-present")
  assert(stitchr.install_info.location == "." and stitchr.install_info.queries == "queries/stitchr")
  assert(stitchr.filetype == "stitchr")
  assert(#tree_notices == 0)
  assert(contains((function()
    local values = {}
    for _, item in ipairs(registrations) do
      values[#values + 1] = item.language .. ":" .. item.filetype
    end
    return values
  end)(), "stitchr:stitchr"))
  assert(filetype_extensions[1].extension.stitchr == "stitchr")
end

local ok, err = xpcall(run, debug.traceback)
for name, entry in pairs(original_modules) do
  package.loaded[name] = entry.value
end
for name, entry in pairs(original_preloads) do
  package.preload[name] = entry.value
end
for _, name in ipairs(env_names) do
  vim.env[name] = original_env[name]
end
package.path = original_package_path
vim.schedule = original_vim.schedule
vim.notify = original_vim.notify
vim.api.nvim_create_augroup = original_vim.api_create_augroup
vim.api.nvim_create_autocmd = original_vim.api_create_autocmd
vim.lsp.config = original_vim.lsp_config
vim.lsp.enable = original_vim.lsp_enable
vim.treesitter.language.register = original_vim.treesitter_register
vim.filetype.add = original_vim.filetype_add
vim.fn.isdirectory = original_vim.fn_isdirectory
vim.fn.filereadable = original_vim.fn_filereadable
vim.keymap.set = original_vim.keymap_set

if not ok then
  error(err, 0)
end
print("tests/runtime.lua: all tests passed")
