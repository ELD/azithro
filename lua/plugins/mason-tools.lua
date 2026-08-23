return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = { "mason-org/mason.nvim" },
  opts = {
    ensure_installed = {
      "eslint_d",
      "codelldb",
      "delve",
      "gofumpt",
      "goimports",
      "hadolint",
      "js-debug-adapter",
      "markdownlint-cli2",
      "prettier",
      "prettierd",
      "shellcheck",
      "shfmt",
      "stylua",
      "taplo",
    },
    auto_update = false,
    run_on_start = false,
  },
}
