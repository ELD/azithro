return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      dockerfile = { "hadolint" },
      javascript = { "eslint_d" },
      javascriptreact = { "eslint_d" },
      markdown = { "markdownlint-cli2" },
      sh = { "shellcheck" },
      typescript = { "eslint_d" },
      typescriptreact = { "eslint_d" },
    }

    local lint_group = vim.api.nvim_create_augroup("azithro_lint", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = lint_group,
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
