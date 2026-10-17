-- Do not rely on startup defaults: native vim.pack confirmation highlighting
-- lives in ftplugin/nvim-pack.lua (not in syntax files or Tree-sitter queries).
vim.cmd("filetype plugin indent on")

require("config.autocmds")
require("config.editor")
require("config.keymaps")
