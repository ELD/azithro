return {
  "mason-org/mason-lspconfig.nvim",
  opts = {
    automatic_enable = {
      exclude = { "rust_analyzer", "ts_ls" },
    },
    ensure_installed = {
      "bashls",
      "cssls",
      "eslint",
      "gopls",
      "graphql",
      "html",
      "jsonls",
      "lua_ls",
      "marksman",
      "rust_analyzer",
      "taplo",
      "ts_ls",
      "yamlls",
    },
  },
  dependencies = {
    "neovim/nvim-lspconfig",
    { "mason-org/mason.nvim", opts = {} },
  },
  config = function(_, opts)
    require("mason").setup()
    require("mason-lspconfig").setup(opts)
  end,
}
