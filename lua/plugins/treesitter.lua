return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	config = function()
		local treesitter = require("nvim-treesitter")
		treesitter.install({
			"bash",
			"css",
			"go",
			"gomod",
			"gosum",
			"gowork",
			"graphql",
			"html",
			"http",
			"javascript",
			"json",
			"lua",
			"markdown",
			"markdown_inline",
			"rust",
			"toml",
			"tsx",
			"typescript",
			"vim",
			"vimdoc",
			"yaml",
			"zig",
		})
		vim.treesitter.language.register("bash", "zsh")
		vim.treesitter.language.register("json", "jsonc")
		vim.treesitter.language.register("stitchr", "stitchr")
		vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
		vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				local treesitter = require("nvim-treesitter")
				local lang = vim.treesitter.language.get_lang(args.match)
				if vim.list_contains(treesitter.get_available(), lang) then
					if not vim.list_contains(treesitter.get_installed(), lang) then
						treesitter.install(lang):wait()
					end
					vim.treesitter.start(args.buf)
				end
			end,
			desc = "Enable nvim-treesitter and install parser if not installed",
		})

		vim.api.nvim_create_autocmd("User", {
			pattern = "TSUpdate",
			callback = function()
				require("nvim-treesitter.parsers").stitchr = {
					install_info = {
						path = "~/workspace/rust/stitchr/tree-sitter-stitchr",
						queries = "queries/stitchr",
						-- files = { "src/parser.c" },
						-- branch = "main",
						-- generate_requires_npm = false,
						-- requires_generate_from_grammar = false,
					},
					filetype = "stitchr",
				}
			end,
		})

		vim.filetype.add({
			extension = {
				stitchr = "stitchr",
			},
		})
	end,
}
