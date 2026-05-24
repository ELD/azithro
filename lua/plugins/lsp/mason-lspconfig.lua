return {
  "mason-org/mason-lspconfig.nvim",
  opts = {},
  dependencies = {
    "neovim/nvim-lspconfig",
    { "mason-org/mason.nvim", opts = {} },
  },
  config = function()
    require("mason").setup();
    require("mason-lspconfig").setup();
  end,
}
