return {
  "pmizio/typescript-tools.nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    "nvim-lua/plenary.nvim",
  },
  ft = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  opts = {
    settings = {
      expose_as_code_action = {
        "add_missing_imports",
        "fix_all",
        "organize_imports",
        "remove_unused",
      },
      tsserver_file_preferences = {
        includeCompletionsForImportStatements = true,
        includeCompletionsForModuleExports = true,
        quotePreference = "auto",
      },
      tsserver_format_options = {
        allowIncompleteCompletions = false,
        allowRenameOfImportPath = true,
      },
    },
  },
  keys = {
    { "<leader>co", "<cmd>TSToolsOrganizeImports<cr>", desc = "TS Organize Imports" },
    { "<leader>cM", "<cmd>TSToolsAddMissingImports<cr>", desc = "TS Add Missing Imports" },
    { "<leader>cu", "<cmd>TSToolsRemoveUnused<cr>", desc = "TS Remove Unused" },
    { "<leader>cF", "<cmd>TSToolsFixAll<cr>", desc = "TS Fix All" },
    { "<leader>cT", "<cmd>TSToolsRenameFile<cr>", desc = "TS Rename File" },
  },
}
