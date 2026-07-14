local function websocket_terminal(command)
  if vim.fn.executable(command) ~= 1 then
    vim.notify(command .. " is not installed or not on PATH", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = command .. " URL: ", default = "ws://localhost:3000" }, function(url)
    if not url or url == "" then
      return
    end

    Snacks.terminal({ command, url }, {
      interactive = true,
      win = {
        position = "bottom",
        height = 0.35,
      },
    })
  end)
end

return {
  "mistweaverco/kulala.nvim",
  ft = { "http", "rest" },
  opts = {
    global_keymaps = false,
    ui = {
      display_mode = "split",
      split_direction = "vertical",
    },
  },
  keys = {
    { "<leader>ar", function() require("kulala").run() end, desc = "API Run Request", ft = { "http", "rest" } },
    { "<leader>aa", function() require("kulala").run_all() end, desc = "API Run All", ft = { "http", "rest" } },
    { "<leader>ap", function() require("kulala").jump_prev() end, desc = "API Previous Request", ft = { "http", "rest" } },
    { "<leader>an", function() require("kulala").jump_next() end, desc = "API Next Request", ft = { "http", "rest" } },
    { "<leader>as", function() require("kulala").show_stats() end, desc = "API Show Stats", ft = { "http", "rest" } },
    { "<leader>at", function() require("kulala").toggle_view() end, desc = "API Toggle View", ft = { "http", "rest" } },
    { "<leader>ac", function() require("kulala").copy() end, desc = "API Copy Request", ft = { "http", "rest" } },
    { "<leader>aw", function() websocket_terminal("websocat") end, desc = "API WebSocket websocat" },
    { "<leader>aW", function() websocket_terminal("wscat") end, desc = "API WebSocket wscat" },
  },
}
