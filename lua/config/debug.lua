local M = {}

local function notify_error(message)
  vim.notify(message, vim.log.levels.ERROR)
end

local function env(name)
  local value = os.getenv(name)
  if value == nil or value == "" then
    return nil
  end
  return value
end

local function absolute(path)
  return type(path) == "string" and path:sub(1, 1) == "/"
end

local function executable_path(path, label)
  if not path then
    notify_error(label .. " is not configured or available on PATH")
    return nil
  end
  if not absolute(path) then
    notify_error(label .. " must be an absolute path: " .. path)
    return nil
  end
  if vim.fn.executable(path) ~= 1 then
    notify_error(label .. " is not executable: " .. path)
    return nil
  end
  return path
end

local function js_server_adapter(callback, provider)
  local command, args
  if provider == "mason" then
    local node = vim.fn.exepath("node")
    if node == "" then
      notify_error("Node.js is required for the JavaScript DAP adapter")
      return
    end

    local ok, package = pcall(function()
      return require("mason-registry").get_package("js-debug-adapter")
    end)
    if not ok or not package:is_installed() then
      notify_error("Mason package js-debug-adapter is not installed")
      return
    end

    local js_debug_path = vim.fs.joinpath(
      package:get_install_path(),
      "js-debug",
      "src",
      "dapDebugServer.js"
    )
    if vim.fn.filereadable(js_debug_path) ~= 1 then
      notify_error("JavaScript DAP adapter not found: " .. js_debug_path)
      return
    end
    command = node
    args = { js_debug_path, "${port}" }
  elseif provider == "nix" then
    local wrapper = env("AZITHRO_JS_DEBUG_COMMAND")
    local server = env("AZITHRO_JS_DEBUG_SERVER")
    if wrapper then
      command = executable_path(wrapper, "AZITHRO_JS_DEBUG_COMMAND")
      if not command then
        return
      end
      args = { "${port}" }
    elseif server then
      if not absolute(server) then
        notify_error("AZITHRO_JS_DEBUG_SERVER must be an absolute path: " .. server)
        return
      end
      if vim.fn.filereadable(server) ~= 1 then
        notify_error("JavaScript DAP server script not found: " .. server)
        return
      end
      command = vim.fn.exepath("node")
      if command == "" then
        notify_error("Node.js is required when using AZITHRO_JS_DEBUG_SERVER")
        return
      end
      args = { server, "${port}" }
    else
      notify_error(
        "Nix JavaScript DAP requires AZITHRO_JS_DEBUG_COMMAND (an executable wrapper) "
          .. "or AZITHRO_JS_DEBUG_SERVER (an absolute adapter script)"
      )
      return
    end
  else
    error("Unsupported debug tool provider: " .. tostring(provider))
  end

  callback({
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = {
      command = command,
      args = args,
    },
  })
end

function M.codelldb_adapter()
  local command = env("AZITHRO_CODELLDB_COMMAND") or vim.fn.exepath("codelldb")
  command = executable_path(command ~= "" and command or nil, "CodeLLDB (AZITHRO_CODELLDB_COMMAND or codelldb on PATH)")
  if not command then
    return
  end

  local args = {}
  local liblldb = env("AZITHRO_LIBLLDB_PATH")
  if liblldb then
    if not absolute(liblldb) then
      notify_error("AZITHRO_LIBLLDB_PATH must be an absolute path: " .. liblldb)
      return
    end
    if vim.fn.filereadable(liblldb) ~= 1 then
      notify_error("CodeLLDB library not found: " .. liblldb)
      return
    end
    args = { "--liblldb", liblldb }
  end
  table.insert(args, "--port")
  table.insert(args, "${port}")

  return {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = {
      command = command,
      args = args,
    },
  }
end

function M.tool_provider()
  local provider = require("config.runtime").tool_provider
  if provider ~= "mason" and provider ~= "nix" then
    error("Unsupported config.runtime.tool_provider: " .. tostring(provider))
  end
  return provider
end

function M.setup_adapters(dap, provider)
  provider = provider or M.tool_provider()
  dap.adapters["pwa-node"] = function(callback)
    js_server_adapter(callback, provider)
  end

  if provider == "nix" then
    dap.adapters.codelldb = function(callback)
      local adapter = M.codelldb_adapter()
      if adapter then
        callback(adapter)
      end
    end
  end
end

return M
