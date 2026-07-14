return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "jay-babu/mason-nvim-dap.nvim",
    "leoluz/nvim-dap-go",
    "theHamsta/nvim-dap-virtual-text",
    {
      "rcarriga/nvim-dap-ui",
      dependencies = { "nvim-neotest/nvim-nio" },
    },
  },
  keys = {
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "DAP Toggle Breakpoint" },
    { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "DAP Conditional Breakpoint" },
    { "<leader>dc", function() require("dap").continue() end, desc = "DAP Continue" },
    { "<leader>di", function() require("dap").step_into() end, desc = "DAP Step Into" },
    { "<leader>do", function() require("dap").step_over() end, desc = "DAP Step Over" },
    { "<leader>dO", function() require("dap").step_out() end, desc = "DAP Step Out" },
    { "<leader>dr", function() require("dap").repl.toggle() end, desc = "DAP REPL" },
    { "<leader>dl", function() require("dap").run_last() end, desc = "DAP Run Last" },
    { "<leader>dt", function() require("dap").terminate() end, desc = "DAP Terminate" },
    { "<leader>du", function() require("dapui").toggle() end, desc = "DAP UI" },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    require("mason-nvim-dap").setup({
      automatic_installation = true,
      ensure_installed = {
        "codelldb",
        "delve",
        "js-debug-adapter",
      },
      handlers = {},
    })

    dapui.setup()
    require("nvim-dap-virtual-text").setup()
    require("dap-go").setup()

    dap.listeners.before.attach.dapui_config = dapui.open
    dap.listeners.before.launch.dapui_config = dapui.open
    dap.listeners.before.event_terminated.dapui_config = dapui.close
    dap.listeners.before.event_exited.dapui_config = dapui.close

    local js_debug_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"
    dap.adapters["pwa-node"] = {
      type = "server",
      host = "localhost",
      port = "${port}",
      executable = {
        command = "node",
        args = { js_debug_path, "${port}" },
      },
    }

    for _, language in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact" }) do
      dap.configurations[language] = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          sourceMaps = true,
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to process",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
        },
      }
    end

    dap.configurations.rust = {
      {
        name = "Launch executable",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
      },
    }
  end,
}
