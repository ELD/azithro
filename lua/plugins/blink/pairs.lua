local function ensure_library()
  local pairs = require("blink.pairs")
  if not pairs.library_available() then
    local ok, err = pairs.download():pwait(60000)
    if not ok then
      error("blink.pairs native library download failed: " .. tostring(err))
    end
    assert(pairs.library_available(), "blink.pairs native library is still unavailable after download")
  end
end

return {
  "saghen/blink.pairs",
  dependencies = "saghen/blink.lib",
  sem_version = "0.*",
  opts = {},
  build = ensure_library,
  config = function(_, opts)
    -- The first vim.pack call installs ALL bundled lock entries, before ZPack
    -- registers build hooks. Ensure native artifacts even on that cold-start path.
    ensure_library()
    require("blink.pairs").setup(opts)
  end,
}
