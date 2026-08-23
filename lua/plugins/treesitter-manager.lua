return {
	"romus204/tree-sitter-manager.nvim",
	dependencies = {}, -- tree-sitter CLI must be installed system-wide
	config = function()
		vim.treesitter.language.register("bash", "zsh")
		vim.treesitter.language.register("json", "jsonc")
		vim.treesitter.language.register("stitchr", "stitchr")
		vim.filetype.add({
			extension = {
				stitchr = "stitchr",
			},
		})

		require("tree-sitter-manager").setup({
			ensure_installed = {
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
			},
			languages = {
				stitchr = {
					install_info = {
						url = vim.fn.expand("file:///Users/edattore/workspace/rust/stitchr/tree-sitter-stitchr"),
						location = ".",
						queries = "queries/stitchr",
					},
					filetype = "stitchr",
				},
			},
			auto_install = true,
			highlight = true,
		})
	end,
}
