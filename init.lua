if vim.fn.has("nvim-0.12") ~= 1 then
	error("Azithro requires Neovim 0.12 or newer")
end

vim.g.__zpack_start_hrtime = (vim.uv or vim.loop).hrtime()

-- Enable the UI2 stuff
require("vim._core.ui2").enable()

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config")

vim.pack.add({ "https://github.com/zuqini/zpack.nvim" })

require("zpack").setup({
	profiling = {
		loader = true,
		require = true,
	},
})
