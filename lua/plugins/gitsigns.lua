return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "" },
      topdelete = { text = "" },
      changedelete = { text = "▎" },
      untracked = { text = "▎" },
    },
    current_line_blame = false,
    current_line_blame_opts = {
      delay = 500,
      virt_text = true,
      virt_text_pos = "eol",
    },
    on_attach = function(bufnr)
      local gitsigns = require("gitsigns")
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      map("n", "]h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gitsigns.nav_hunk("next")
        end
      end, "Next Git Hunk")

      map("n", "[h", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gitsigns.nav_hunk("prev")
        end
      end, "Previous Git Hunk")

      map("n", "<leader>ghs", gitsigns.stage_hunk, "Git Stage Hunk")
      map("n", "<leader>ghr", gitsigns.reset_hunk, "Git Reset Hunk")
      map("v", "<leader>ghs", function()
        gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Git Stage Hunk")
      map("v", "<leader>ghr", function()
        gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Git Reset Hunk")
      map("n", "<leader>ghS", gitsigns.stage_buffer, "Git Stage Buffer")
      map("n", "<leader>ghR", gitsigns.reset_buffer, "Git Reset Buffer")
      map("n", "<leader>ghp", gitsigns.preview_hunk, "Git Preview Hunk")
      map("n", "<leader>ghb", function()
        gitsigns.blame_line({ full = true })
      end, "Git Blame Line")
      map("n", "<leader>ghB", gitsigns.toggle_current_line_blame, "Git Toggle Line Blame")
      map("n", "<leader>ghd", gitsigns.diffthis, "Git Diff This")
      map("n", "<leader>ghD", function()
        gitsigns.diffthis("~")
      end, "Git Diff This Against Previous")
      map("n", "<leader>ghq", gitsigns.setqflist, "Git Hunks Quickfix")

      map({ "o", "x" }, "ih", gitsigns.select_hunk, "Git Hunk")
    end,
  },
}
