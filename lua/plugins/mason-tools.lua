return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  dependencies = { "mason-org/mason.nvim" },
  opts = {
    ensure_installed = {
      "eslint_d",
      "gofumpt",
      "goimports",
      "hadolint",
      "markdownlint-cli2",
      "prettier",
      "prettierd",
      "shellcheck",
      "shfmt",
      "stylua",
      "taplo",
    },
    auto_update = false,
    run_on_start = true,
  },
}
