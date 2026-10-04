return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    delay = 400,
    icons = {
      mappings = true,
    },
    spec = {
      { "<leader>a", group = "api" },
      { "<leader>b", group = "buffer" },
      { "<leader>c", group = "code" },
      { "<leader>d", group = "debug" },
      { "<leader>f", group = "find" },
      { "<leader>g", group = "git" },
      { "<leader>gh", group = "hunks" },
      { "<leader>m", group = "markdown" },
      { "<leader>o", group = "outline" },
      { "<leader>s", group = "search" },
      { "<leader>t", group = "test" },
      { "<leader>u", group = "ui" },
      { "<leader>x", group = "diagnostics" },
    },
  },
}
