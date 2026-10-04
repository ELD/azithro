local runtime = require("config.runtime")

if runtime.tool_provider == "nix" then
  return {
    "neovim/nvim-lspconfig",
    config = function()
      require("config.lsp")
      -- Mason's automatic_enable only considers Mason-installed servers.
      -- Nix executables instead come from the Neovim wrapper's PATH.
      vim.lsp.enable({
        "bashls", "cssls", "eslint", "gopls", "graphql", "html", "jsonls",
        "lua_ls", "marksman", "taplo", "yamlls",
      })
    end,
  }
end

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
    require("config.lsp")
    require("mason-lspconfig").setup(opts)
  end,
}
