return {
  "nvim-neotest/neotest",
  dependencies = {
    "antoinemadec/FixCursorHold.nvim",
    "fredrikaverpil/neotest-golang",
    "marilari88/neotest-vitest",
    "nvim-lua/plenary.nvim",
    "nvim-neotest/nvim-nio",
    "nvim-treesitter/nvim-treesitter",
    "rouge8/neotest-rust",
  },
  keys = {
    { "<leader>tt", function() require("neotest").run.run() end, desc = "Test Nearest" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test File" },
    { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug Nearest Test" },
    { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test Summary" },
    { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Test Output" },
    { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Test Output Panel" },
    { "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Test Watch File" },
    { "<leader>tS", function() require("neotest").run.stop() end, desc = "Test Stop" },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-golang")({}),
        require("neotest-rust"),
        require("neotest-vitest"),
      },
    })
  end,
}
