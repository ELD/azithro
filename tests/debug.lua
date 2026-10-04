package.path = "./lua/?.lua;./lua/?/init.lua;./lua/plugins/?.lua;" .. package.path

local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function contains(values, wanted)
  for _, value in ipairs(values) do
    if value == wanted then
      return true
    end
  end
  return false
end

local function includes(text, fragment)
  assert(text:find(fragment, 1, true), "expected '" .. text .. "' to contain '" .. fragment .. "'")
end

local env_values, paths, executable_paths, readable_paths, notifications = {}, {}, {}, {}, {}
local real_getenv = os.getenv
os.getenv = function(name)
  return env_values[name]
end

vim.fn = {
  exepath = function(name)
    return paths[name] or ""
  end,
  executable = function(path)
    return executable_paths[path] and 1 or 0
  end,
  filereadable = function(path)
    return readable_paths[path] and 1 or 0
  end,
  input = function()
    return ""
  end,
  getcwd = function()
    return "/workspace"
  end,
}
vim.fs.joinpath = function(...)
  return table.concat({ ... }, "/"):gsub("/+$", "")
end
vim.notify = function(message, level)
  table.insert(notifications, { message = message, level = level })
end

local function clear_state()
  env_values, paths, executable_paths, readable_paths, notifications = {}, {}, {}, {}, {}
end

local function setup_dap(provider)
  local debug = require("config.debug")
  local dap = { adapters = {}, configurations = {} }
  debug.setup_adapters(dap, provider)
  return dap
end

local function invoke(adapter)
  local result
  adapter(function(value)
    result = value
  end)
  return result
end

local function last_error()
  assert(#notifications > 0, "expected an error notification")
  eq(notifications[#notifications].level, vim.log.levels.ERROR, "notification severity")
  return notifications[#notifications].message
end

-- Nix JavaScript wrapper is used directly; Nix mode does not consult Mason.
clear_state()
package.loaded["mason-registry"] = nil
package.preload["mason-registry"] = function()
  error("Nix debug must not load mason-registry")
end
env_values.AZITHRO_JS_DEBUG_COMMAND = "/nix/store/js-debug/bin/js-debug-adapter"
executable_paths[env_values.AZITHRO_JS_DEBUG_COMMAND] = true
local nix_dap = setup_dap("nix")
local js = invoke(nix_dap.adapters["pwa-node"])
eq(js.type, "server")
eq(js.host, "localhost")
eq(js.port, "${port}")
eq(js.executable.command, env_values.AZITHRO_JS_DEBUG_COMMAND)
eq(js.executable.args[1], "${port}")
eq(#notifications, 0)

-- Nix also supports the explicit node + script contract.
clear_state()
env_values.AZITHRO_JS_DEBUG_SERVER = "/nix/store/js-debug/src/dapDebugServer.js"
paths.node = "/nix/store/node/bin/node"
readable_paths[env_values.AZITHRO_JS_DEBUG_SERVER] = true
nix_dap = setup_dap("nix")
js = invoke(nix_dap.adapters["pwa-node"])
eq(js.executable.command, paths.node)
eq(js.executable.args[1], env_values.AZITHRO_JS_DEBUG_SERVER)
eq(js.executable.args[2], "${port}")

-- Missing and malformed Nix tool settings fail clearly without invoking callbacks.
clear_state()
nix_dap = setup_dap("nix")
eq(invoke(nix_dap.adapters["pwa-node"]), nil)
includes(last_error(), "AZITHRO_JS_DEBUG_COMMAND")
clear_state()
env_values.AZITHRO_JS_DEBUG_COMMAND = "js-debug-adapter"
nix_dap = setup_dap("nix")
eq(invoke(nix_dap.adapters["pwa-node"]), nil)
includes(last_error(), "absolute path")

-- Nix CodeLLDB uses the supplied executable, optional liblldb, and a port server.
clear_state()
env_values.AZITHRO_CODELLDB_COMMAND = "/nix/store/codelldb/bin/codelldb"
env_values.AZITHRO_LIBLLDB_PATH = "/nix/store/codelldb/lib/liblldb.so"
executable_paths[env_values.AZITHRO_CODELLDB_COMMAND] = true
readable_paths[env_values.AZITHRO_LIBLLDB_PATH] = true
nix_dap = setup_dap("nix")
local codelldb = invoke(nix_dap.adapters.codelldb)
eq(codelldb.type, "server")
eq(codelldb.host, "localhost")
eq(codelldb.port, "${port}")
eq(codelldb.executable.command, env_values.AZITHRO_CODELLDB_COMMAND)
eq(codelldb.executable.args[1], "--liblldb")
eq(codelldb.executable.args[2], env_values.AZITHRO_LIBLLDB_PATH)
eq(codelldb.executable.args[3], "--port")
eq(codelldb.executable.args[4], "${port}")
clear_state()
paths.codelldb = "/nix/store/codelldb/bin/codelldb"
executable_paths[paths.codelldb] = true
nix_dap = setup_dap("nix")
codelldb = invoke(nix_dap.adapters.codelldb)
eq(codelldb.executable.command, paths.codelldb)
eq(codelldb.executable.args[1], "--port")
clear_state()
nix_dap = setup_dap("nix")
eq(invoke(nix_dap.adapters.codelldb), nil)
includes(last_error(), "CodeLLDB")

-- Mason retains the package-based JavaScript adapter lookup and clear failures.
clear_state()
paths.node = "/usr/bin/node"
local mason_package = {
  is_installed = function()
    return true
  end,
  get_install_path = function()
    return "/mason/packages/js-debug-adapter"
  end,
}
package.loaded["mason-registry"] = {
  get_package = function(name)
    eq(name, "js-debug-adapter")
    return mason_package
  end,
}
local mason_script = "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"
readable_paths[mason_script] = true
local mason_dap = setup_dap("mason")
js = invoke(mason_dap.adapters["pwa-node"])
eq(js.executable.command, paths.node)
eq(js.executable.args[1], mason_script)
eq(js.executable.args[2], "${port}")
clear_state()
paths.node = "/usr/bin/node"
package.loaded["mason-registry"] = {
  get_package = function()
    return { is_installed = function() return false end }
  end,
}
mason_dap = setup_dap("mason")
eq(invoke(mason_dap.adapters["pwa-node"]), nil)
includes(last_error(), "Mason package js-debug-adapter is not installed")
clear_state()
mason_dap = setup_dap("mason")
eq(invoke(mason_dap.adapters["pwa-node"]), nil)
includes(last_error(), "Node.js is required")

local function dap_mocks()
  local dap = {
    adapters = {},
    configurations = {},
    listeners = {
      before = {
        attach = {},
        launch = {},
        event_terminated = {},
        event_exited = {},
      },
    },
  }
  local dapui = { setup = function() end, open = function() end, close = function() end }
  package.loaded["dap"] = dap
  package.loaded["dap.utils"] = { pick_process = function() end }
  package.loaded["dapui"] = dapui
  package.loaded["nvim-dap-virtual-text"] = { setup = function() end }
  package.loaded["dap-go"] = { setup = function() end }
  return dap
end

-- Plugin spec dependencies and config stay provider-specific; Nix never loads Mason.
package.loaded["config.runtime"] = { tool_provider = "nix" }
package.loaded["plugins.dap"] = nil
local spec = require("plugins.dap")
assert(not contains(spec.dependencies, "jay-babu/mason-nvim-dap.nvim"), "Nix spec includes Mason DAP")
clear_state()
local setup_dap_table = dap_mocks()
package.loaded["mason-nvim-dap"] = nil
package.preload["mason-nvim-dap"] = function()
  error("Nix DAP config must not load mason-nvim-dap")
end
spec.config()
assert(setup_dap_table.adapters.codelldb, "Nix config did not register CodeLLDB")
eq(setup_dap_table.configurations.javascript[1].type, "pwa-node")
eq(setup_dap_table.configurations.typescriptreact[2].request, "attach")
eq(setup_dap_table.configurations.rust[1].type, "codelldb")

-- Rustaceanvim's own commands share the explicit Nix adapter, even off PATH.
clear_state()
env_values.AZITHRO_CODELLDB_COMMAND = "/nix/store/extension/adapter/codelldb"
executable_paths[env_values.AZITHRO_CODELLDB_COMMAND] = true
local old_rust_config = vim.g.rustaceanvim
local rust_spec = dofile("lua/plugins/rust.lua")
rust_spec.init()
local rust_adapter = vim.g.rustaceanvim.dap.adapter()
eq(rust_adapter.executable.command, env_values.AZITHRO_CODELLDB_COMMAND)
eq(rust_adapter.executable.args[1], "--port")
vim.g.rustaceanvim = old_rust_config

package.loaded["config.runtime"] = { tool_provider = "mason" }
package.loaded["plugins.dap"] = nil
spec = require("plugins.dap")
assert(contains(spec.dependencies, "jay-babu/mason-nvim-dap.nvim"), "Mason spec omitted Mason DAP")
local mason_setup_count = 0
package.loaded["mason-nvim-dap"] = {
  setup = function(opts)
    eq(opts.automatic_installation, false)
    eq(next(opts.handlers), nil)
    mason_setup_count = mason_setup_count + 1
  end,
}
setup_dap_table = dap_mocks()
spec.config()
eq(mason_setup_count, 1, "Mason adapter setup count")
assert(setup_dap_table.configurations.rust[1], "Rust configuration was lost")

package.loaded["mason-registry"] = nil
package.loaded["mason-nvim-dap"] = nil
package.loaded["dap"] = nil
package.loaded["dap.utils"] = nil
package.loaded["dapui"] = nil
package.loaded["dap-go"] = nil
package.loaded["nvim-dap-virtual-text"] = nil
package.loaded["plugins.dap"] = nil
package.loaded["config.runtime"] = nil
package.preload["mason-registry"] = nil
package.preload["mason-nvim-dap"] = nil
os.getenv = real_getenv

print("debug adapter tests passed")
