return {
	"saghen/blink.cmp",
	-- optional: provides snippets for the snippet source
	dependencies = {
		"rafamadriz/friendly-snippets",
		{
			"saghen/blink.compat",
			sem_ver = "2.*",
		},
	},

	-- use a release tag to download pre-built binaries
	version = vim.version.range("1.*"),
	-- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
	-- build = 'cargo build --release',
	-- If you use nix, you can build from source using latest nightly rust with:
	-- build = 'nix run .#build-plugin',

	init = function()
		local function set_completion_highlights()
			local highlights = {
				BlinkCmpKindText = "#c8d3f5",
				BlinkCmpKindMethod = "#82aaff",
				BlinkCmpKindFunction = "#82aaff",
				BlinkCmpKindConstructor = "#fca7ea",
				BlinkCmpKindField = "#ffc777",
				BlinkCmpKindVariable = "#c8d3f5",
				BlinkCmpKindClass = "#ff966c",
				BlinkCmpKindInterface = "#65bcff",
				BlinkCmpKindModule = "#c099ff",
				BlinkCmpKindProperty = "#ffc777",
				BlinkCmpKindUnit = "#86e1fc",
				BlinkCmpKindValue = "#c3e88d",
				BlinkCmpKindEnum = "#ff966c",
				BlinkCmpKindKeyword = "#fca7ea",
				BlinkCmpKindSnippet = "#c3e88d",
				BlinkCmpKindColor = "#ff757f",
				BlinkCmpKindFile = "#82aaff",
				BlinkCmpKindReference = "#c099ff",
				BlinkCmpKindFolder = "#82aaff",
				BlinkCmpKindEnumMember = "#c3e88d",
				BlinkCmpKindConstant = "#ff966c",
				BlinkCmpKindStruct = "#ff966c",
				BlinkCmpKindEvent = "#ffc777",
				BlinkCmpKindOperator = "#89ddff",
				BlinkCmpKindTypeParameter = "#65bcff",
			}

			for group, color in pairs(highlights) do
				vim.api.nvim_set_hl(0, group, { fg = color })
			end

			vim.api.nvim_set_hl(0, "BlinkCmpLabelMatch", { fg = "#82aaff", bold = true })
			vim.api.nvim_set_hl(0, "BlinkCmpSource", { fg = "#7f849c", italic = true })
			vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder", { fg = "#82aaff" })
			vim.api.nvim_set_hl(0, "BlinkCmpDocBorder", { fg = "#82aaff" })
			vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelpBorder", { fg = "#82aaff" })
		end

		set_completion_highlights()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("azithro_blink_highlights", { clear = true }),
			callback = set_completion_highlights,
		})
	end,

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		-- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
		-- 'super-tab' for mappings similar to vscode (tab to accept)
		-- 'enter' for enter to accept
		-- 'none' for no mappings
		--
		-- All presets have the following mappings:
		-- C-space: Open menu or open docs if already open
		-- C-n/C-p or Up/Down: Select next/previous item
		-- C-e: Hide menu
		-- C-k: Toggle signature help (if signature.enabled = true)
		--
		-- See :h blink-cmp-config-keymap for defining your own keymap
		keymap = { preset = "super-tab" },

		appearance = {
			-- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
			-- Adjusts spacing to ensure icons are aligned
			kind_icons = {
				Text = "󰉿",
				Method = "󰊕",
				Function = "󰊕",
				Constructor = "󰒓",
				Field = "󰜢",
				Variable = "󰆦",
				Class = "󰠱",
				Interface = "",
				Module = "󰏗",
				Property = "󰜢",
				Unit = "󰑭",
				Value = "󰎠",
				Enum = "",
				Keyword = "󰌋",
				Snippet = "",
				Color = "󰏘",
				File = "󰈙",
				Reference = "󰈇",
				Folder = "󰉋",
				EnumMember = "",
				Constant = "󰏿",
				Struct = "󰙅",
				Event = "",
				Operator = "󰆕",
				TypeParameter = "󰊄",
			},
			nerd_font_variant = "mono",
		},

		completion = {
			accept = { auto_brackets = { enabled = true } },
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 250,
				window = {
					border = "rounded",
				},
			},
			ghost_text = {
				enabled = true,
			},
			list = {
				selection = {
					preselect = true,
					auto_insert = false,
				},
			},
			menu = {
				border = "rounded",
				draw = {
					treesitter = { "lsp" },
					columns = {
						{ "kind_icon" },
						{ "label", "label_description", gap = 1 },
						{ "source_name" },
					},
				},
			},
		},

		-- Default list of enabled providers defined so that you can extend it
		-- elsewhere in your config, without redefining it, due to `opts_extend`
		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
		},

		signature = {
			enabled = true,
			window = {
				border = "rounded",
			},
		},

		-- (Default) Rust fuzzy matcher for typo resistance and significantly better performance
		-- You may use a lua implementation instead by using `implementation = "lua"` or fallback to the lua implementation,
		-- when the Rust fuzzy matcher is not available, by using `implementation = "prefer_rust"`
		--
		-- See the fuzzy documentation for more information
		fuzzy = { implementation = "prefer_rust_with_warning" },
	},
	opts_extend = { "sources.default" },
}
