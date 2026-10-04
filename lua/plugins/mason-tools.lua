return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  enabled = require("config.runtime").tool_provider == "mason",
  dependencies = { "mason-org/mason.nvim" },
  opts = {
    ensure_installed = {
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
