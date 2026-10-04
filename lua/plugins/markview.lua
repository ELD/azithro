local filetypes = { "markdown", "quarto", "rmd" }

return {
	"OXY2DEV/markview.nvim",
	-- Upstream requires startup loading; the colorscheme loads first at priority 1000.
	lazy = false,
	dependencies = {
		"saghen/blink.cmp",
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		preview = {
			filetypes = filetypes,
			icon_provider = "devicons",
			map_gx = false, -- Keep Neovim's existing URL-opening mapping.
			ignore_buftypes = {}, -- Also render Markdown LSP hovers/completion documentation.
			modes = { "n", "no", "c", "i" },
			hybrid_modes = { "i" }, -- Reveal the edited node while keeping the rest rendered.
		},
	},
	config = function(_, opts)
		require("markview").setup(opts)
		-- Dependencies are configured first; register even if startup happened after VimEnter.
		require("markview.integrations").setup()
		require("markview.extras.editor").setup()
		require("markview.extras.headings").setup()
		require("markview.extras.checkboxes").setup({ default = "x" })
	end,
	keys = {
		{ "<leader>mp", "<Cmd>Markview toggle<CR>", ft = filetypes, desc = "Toggle Markdown preview" },
		{ "<leader>mP", "<Cmd>Markview Toggle<CR>", ft = filetypes, desc = "Toggle all Markdown previews" },
		{ "<leader>ms", "<Cmd>Markview splitToggle<CR>", ft = filetypes, desc = "Toggle Markdown split preview" },
		{ "<leader>mh", "<Cmd>Markview hybridToggle<CR>", ft = filetypes, desc = "Toggle Markdown hybrid mode" },
		{ "<leader>me", "<Cmd>Editor edit<CR>", ft = filetypes, desc = "Edit fenced code block" },
		{ "<leader>mc", "<Cmd>Editor create<CR>", ft = filetypes, desc = "Create fenced code block" },
		{ "<leader>mx", "<Cmd>Checkbox toggle<CR>", ft = filetypes, desc = "Toggle Markdown checkbox" },
		{ "<leader>mX", "<Cmd>Checkbox interactive<CR>", ft = filetypes, desc = "Choose Markdown checkbox state" },
		{ "<leader>m[", "<Cmd>Heading decrease<CR>", ft = filetypes, desc = "Decrease heading level" },
		{ "<leader>m]", "<Cmd>Heading increase<CR>", ft = filetypes, desc = "Increase heading level" },
	},
}
