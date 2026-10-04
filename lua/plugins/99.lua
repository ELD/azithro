local runtime = require("config.runtime")

return {
  "ThePrimeagen/99",
  enabled = runtime.ai_enabled,
  config = function()
    local ai = require("99")
    ai.setup({
      provider = ai.Providers.OpencodeProvider,
      model = runtime.ai_model, -- nil retains the provider/plugin default.
      -- Keep requests inside the project to respect the provider's permissions.
      -- Add this directory to project/global Git ignores when enabling AI.
      tmp_dir = "./.azithro-tmp",
      completion = { source = "blink", files = {} },
      md_files = { "AGENT.md" },
    })
    vim.keymap.set("v", "<leader>9v", ai.visual, { desc = "AI Visual Request" })
    vim.keymap.set("n", "<leader>9x", ai.stop_all_requests, { desc = "AI Cancel Requests" })
    vim.keymap.set("n", "<leader>9s", ai.search, { desc = "AI Search" })
  end,
}
