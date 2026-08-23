return {
  "saghen/blink.pairs",
  dependencies = "saghen/blink.lib",
  sem_version = "0.*",
  opts = {},
  build = function()
    require("blink.pairs").download():pwait(60000)
  end,
}
