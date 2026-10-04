return {
  "rachartier/tiny-cmdline.nvim",
  enabled = require("config.runtime").ui2_enabled,
  event = "VeryLazy",
  config = function()
    require("tiny-cmdline").setup()
  end,
}
