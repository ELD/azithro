return {
  "stevearc/aerial.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    attach_mode = "window",
    backends = { "lsp", "treesitter", "markdown", "man" },
    filter_kind = false,
    layout = {
      default_direction = "prefer_right",
      max_width = { 40, 0.3 },
      min_width = 28,
    },
    show_guides = true,
  },
  keys = {
    { "<leader>oo", "<cmd>AerialToggle<cr>", desc = "Toggle Outline" },
    { "<leader>of", "<cmd>AerialNavToggle<cr>", desc = "Toggle Outline Float" },
    { "<leader>on", "<cmd>AerialNext<cr>", desc = "Next Symbol" },
    { "<leader>op", "<cmd>AerialPrev<cr>", desc = "Previous Symbol" },
  },
}
