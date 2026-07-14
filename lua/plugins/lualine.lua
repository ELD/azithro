return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  init = function()
    vim.o.laststatus = 3
  end,
  opts = function()
    local colors = {
      bg = "NONE",
      fg = "#c8d3f5",
      dark = "#1b1d2b",
      muted = "#828bb8",
      blue = "#82aaff",
      cyan = "#86e1fc",
      green = "#c3e88d",
      orange = "#ff966c",
      purple = "#c099ff",
      red = "#ff757f",
      yellow = "#ffc777",
    }

    local mode_colors = {
      command = colors.yellow,
      insert = colors.green,
      normal = colors.blue,
      replace = colors.red,
      terminal = colors.cyan,
      visual = colors.purple,
    }

    local function mode_section(color)
      return {
        a = { fg = colors.dark, bg = color, gui = "bold" },
        b = { fg = colors.fg, bg = colors.dark },
        c = { fg = colors.fg, bg = colors.bg },
      }
    end

    local theme = {
      command = mode_section(mode_colors.command),
      insert = mode_section(mode_colors.insert),
      normal = mode_section(mode_colors.normal),
      replace = mode_section(mode_colors.replace),
      terminal = mode_section(mode_colors.terminal),
      visual = mode_section(mode_colors.visual),
      inactive = {
        a = { fg = colors.muted, bg = colors.dark, gui = "bold" },
        b = { fg = colors.muted, bg = colors.dark },
        c = { fg = colors.muted, bg = colors.bg },
      },
    }

    local function lsp_clients()
      local clients = vim.lsp.get_clients({ bufnr = 0 })
      if #clients == 0 then
        return "no lsp"
      end

      local names = {}
      for _, client in ipairs(clients) do
        if client.name ~= "null-ls" then
          table.insert(names, client.name)
        end
      end

      if #names == 0 then
        return "no lsp"
      end

      table.sort(names)
      return table.concat(names, ",")
    end

    local function formatter_status()
      local ok, conform = pcall(require, "conform")
      if not ok then
        return ""
      end

      local formatters = conform.list_formatters(0)
      if #formatters == 0 then
        return ""
      end

      local names = {}
      for _, formatter in ipairs(formatters) do
        if formatter.available then
          table.insert(names, formatter.name)
        end
      end

      if #names == 0 then
        return ""
      end

      table.sort(names)
      return table.concat(names, ",")
    end

    return {
      options = {
        component_separators = "",
        disabled_filetypes = {
          statusline = { "alpha", "dashboard", "snacks_dashboard" },
        },
        globalstatus = true,
        section_separators = { left = "", right = "" },
        theme = theme,
      },
      sections = {
        lualine_a = {
          {
            "mode",
            padding = { left = 1, right = 1 },
          },
        },
        lualine_b = {
          {
            "filename",
            file_status = true,
            newfile_status = true,
            path = 1,
            symbols = {
              modified = " ●",
              readonly = " ",
              unnamed = "[No Name]",
              newfile = "[New]",
            },
          },
          {
            "branch",
            icon = "",
            color = { fg = colors.purple, bg = colors.dark, gui = "bold" },
          },
          {
            "diff",
            colored = true,
            symbols = { added = "+", modified = "~", removed = "-" },
          },
        },
        lualine_c = {
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" },
          },
        },
        lualine_x = {
          {
            lsp_clients,
            icon = "",
            color = { fg = colors.cyan, gui = "bold" },
          },
          {
            formatter_status,
            icon = "󰉢",
            color = { fg = colors.green, gui = "bold" },
          },
          {
            "filetype",
            colored = true,
            icon_only = false,
          },
        },
        lualine_y = {
          "progress",
        },
        lualine_z = {
          "location",
        },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {
          {
            "filename",
            file_status = true,
            path = 1,
          },
        },
        lualine_c = {},
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      extensions = { "fugitive", "lazy", "mason", "oil", "quickfix", "trouble" },
    }
  end,
}
