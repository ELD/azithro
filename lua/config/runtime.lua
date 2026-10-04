local M = {}

local function setting(name)
  local value = vim.env[name]
  return value ~= nil and value ~= "" and value or nil
end

local function boolean(name, default)
  local value = setting(name)
  if value == nil then
    return default
  elseif value == "1" or value == "true" then
    return true
  elseif value == "0" or value == "false" then
    return false
  end
  error(name .. " must be 1, 0, true or false")
end

local function path(name)
  local value = setting(name)
  if value and (value:sub(1, 1) ~= "/" or value:find("%z")) then
    error(name .. " must be an absolute path")
  end
  return value and vim.fs.normalize(value) or nil
end

M.tool_provider = setting("AZITHRO_TOOL_PROVIDER") or "mason"
if M.tool_provider ~= "mason" and M.tool_provider ~= "nix" then
  error("AZITHRO_TOOL_PROVIDER must be mason or nix")
end

M.pack_lock = path("AZITHRO_PACK_LOCK")
M.stitchr_path = path("AZITHRO_STITCHR_PATH")
M.experimental_ui = boolean("AZITHRO_EXPERIMENTAL_UI", true)
M.profiling = boolean("AZITHRO_PROFILING", false)
M.ai_enabled = boolean("AZITHRO_AI_ENABLED", false)
M.ai_model = setting("AZITHRO_AI_MODEL")
M.ui2_enabled = false

function M.setup()
  -- This must precede even the ZPack bootstrap: vim.pack caches its lock on first use.
  require("config.pack").setup({ path = M.pack_lock })

  if not M.experimental_ui then
    return
  end
  local ok, ui = pcall(require, "vim._core.ui2")
  local reason = ok and "enable() unavailable" or tostring(ui)
  if ok and type(ui) == "table" and type(ui.enable) == "function" then
    local enabled, err = pcall(ui.enable)
    M.ui2_enabled = enabled
    if enabled then
      return
    end
    -- Best effort cleanup if a changing private API failed part way through setup.
    if type(ui.disable) == "function" then
      pcall(ui.disable)
    end
    reason = tostring(err)
  end
  vim.schedule(function()
    vim.notify("Azithro: experimental UI unavailable; using native UI (" .. reason .. ")", vim.log.levels.WARN)
  end)
end

return M
