-- Snacks.dashboard's startup section probes lazy.stats. This compatibility shim
-- reports ZPack statistics without installing or depending on lazy.nvim.
local M = {}

local uv = vim.uv or vim.loop

local start_ns = vim.g.__zpack_start_hrtime or uv.hrtime()

local cached_startup_ms = 0

local function pack_dirs(glob)
  local packpath = vim.o.packpath
  return vim.fn.globpath(packpath, glob, false, true) or {}
end

local function plugin_counts()
  local ok, zpack_api = pcall(require, "zpack.api")
  if ok and type(zpack_api.get_plugins) == "function" then
    local plugins = zpack_api.get_plugins()
    local loaded = 0

    for _, plugin in ipairs(plugins) do
      if plugin.status == "loaded" then
        loaded = loaded + 1
      end
    end

    return #plugins, loaded
  end

  if vim.pack and type(vim.pack.get) == "function" then
    local ok, packs = pcall(vim.pack.get)
    if ok and type(packs) == "table" then
      local count = 0
      local loaded = 0
      for _, plugin in pairs(packs) do
        local name = plugin.spec and plugin.spec.name or ""
        if name ~= "zpack.nvim" then
          count = count + 1
          if plugin.active then
            loaded = loaded + 1
          end
        end
      end
      return count, loaded
    end
  end

  local start = pack_dirs("pack/*/start/*")
  local opt = pack_dirs("pack/*/opt/*")
  local loaded = #start
  local rtp = {}

  for _, path in ipairs(vim.opt.runtimepath:get()) do
    rtp[path] = true
  end

  for _, path in ipairs(opt) do
    if rtp[path] then
      loaded = loaded + 1
    end
  end

  return #start + #opt, loaded
end

local function update_startup_ms()
  cached_startup_ms = (uv.hrtime() - start_ns) / 1e6
end

if vim.v.vim_did_enter == 1 then
  update_startup_ms()
else
  vim.api.nvim_create_autocmd("UIEnter", {
    once = true,
    callback = update_startup_ms,
  })
end

function M.stats()
  local count, loaded = plugin_counts()

  if cached_startup_ms == 0 then
    update_startup_ms()
  end

  return {
    startuptime = cached_startup_ms,
    count = count,
    loaded = loaded,
    real_cputime = false,
    times = {},
  }
end

return M
