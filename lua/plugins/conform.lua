return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    formatters_by_ft = {
      css = { "prettierd", "prettier", stop_after_first = true },
      go = { "goimports", "gofumpt" },
      graphql = { "prettierd", "prettier", stop_after_first = true },
      html = { "prettierd", "prettier", stop_after_first = true },
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      json = { "prettierd", "prettier", stop_after_first = true },
      jsonc = { "prettierd", "prettier", stop_after_first = true },
      lua = { "stylua" },
      markdown = { "prettierd", "prettier", stop_after_first = true },
      rust = { "rustfmt" },
      sh = { "shfmt" },
      toml = { "taplo" },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", stop_after_first = true },
      yaml = { "prettierd", "prettier", stop_after_first = true },
    },
    format_on_save = function(bufnr)
      local disabled_filetypes = {
        c = true,
        cpp = true,
      }

      return {
        async = false,
        lsp_format = disabled_filetypes[vim.bo[bufnr].filetype] and "never" or "fallback",
        timeout_ms = 1000,
      }
    end,
  },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      desc = "Format",
      mode = { "n", "x" },
    },
  },
}
