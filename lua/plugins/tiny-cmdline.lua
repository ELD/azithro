return {
  "rachartier/tiny-cmdline.nvim",
  event = "VeryLazy",
  config = function()
    require("tiny-cmdline").setup()
  end,
}
