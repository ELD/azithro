return {
	"romus204/tree-sitter-manager.nvim",
	dependencies = {}, -- tree-sitter CLI must be installed system-wide
	config = function()
		vim.treesitter.language.register("bash", "zsh")
		vim.treesitter.language.register("json", "jsonc")
		local languages = {}
		local stitchr = require("config.runtime").stitchr_path
		if stitchr then
			if vim.fn.isdirectory(stitchr) == 1 and vim.fn.filereadable(stitchr .. "/grammar.js") == 1 then
				vim.treesitter.language.register("stitchr", "stitchr")
				vim.filetype.add({ extension = { stitchr = "stitchr" } })
				languages.stitchr = {
					install_info = {
						url = "file://" .. stitchr,
						location = ".",
						queries = "queries/stitchr",
					},
					filetype = "stitchr",
				}
			else
				vim.notify("Azithro: Stitchr grammar checkout not found: " .. stitchr, vim.log.levels.WARN)
			end
		end

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
			languages = languages,
			auto_install = true,
			highlight = true,
		})
	end,
}
