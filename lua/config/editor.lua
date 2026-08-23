local opts = {
  autoindent = true,
  autoread = true,
  backspace = { "start", "eol", "indent" },
  backup = false,
  clipboard = "unnamedplus",
  cmdheight = 0,
  -- colorcolumn = { 80, 120 },
  completeopt = { "menu", "menuone", "noselect" },
  conceallevel = 1,
  confirm = true,
  cursorline = true,
  errorbells = false,
  expandtab = true,
  fileencoding = "utf-8",
  fillchars = {
    eob = " ",
    fold = " ",
    foldclose = "",
    foldopen = "",
    foldsep = " ",
  },
  foldexpr = vim.treesitter.foldexpr,
  foldenable = false,
  foldlevel = 99,
  foldlevelstart = 99,
  foldmethod = "expr",
  hidden = true,
  hlsearch = true,
  ignorecase = true,
  inccommand = "split",
  incsearch = true,
  list = true,
  listchars = {
    tab = "»·",
    trail = "·",
    nbsp = "␣",
  },
  mouse = "a",
  number = true,
  pumheight = 10,
  relativenumber = true,
  scrolloff = 8,
  shiftwidth = 2,
  showmode = false,
  sidescrolloff = 8,
  signcolumn = "yes",
  smartcase = true,
  smartindent = true,
  softtabstop = 2,
  splitkeep = "screen",
  splitbelow = true,
  splitright = true,
  tabstop = 2,
  termguicolors = true,
  timeoutlen = 300,
  undofile = true,
  updatetime = 250,
  virtualedit = "block",
  wrap = false,
}

for key, value in pairs(opts) do
  vim.opt[key] = value
end

vim.opt.shortmess:append("c")

if vim.fn.exists("+winborder") == 1 then
  vim.o.winborder = "rounded"
end
