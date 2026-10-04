if vim.fn.has("nvim-0.13") ~= 1 then
	error("Azithro requires Neovim 0.13+ with packlockfile support; use a compatible pinned nightly")
end

vim.g.__zpack_start_hrtime = (vim.uv or vim.loop).hrtime()

local runtime = require("config.runtime")
runtime.setup()

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config")

vim.pack.add({ "https://github.com/zuqini/zpack.nvim" })

require("zpack").setup({
	profiling = {
		loader = runtime.profiling,
		require = runtime.profiling,
	},
})
