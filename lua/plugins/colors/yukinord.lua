return {
  "adibhanna/yukinord.nvim",
  config = function()
    require("yukinord").setup({
      transparent = true,
      transparent_sidebar = true,
    })
    -- vim.cmd([[colorscheme yukinord]])
  end,
}
