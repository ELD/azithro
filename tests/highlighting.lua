local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

-- Start without filetype plugins, as can happen with alternate startup wrappers.
vim.cmd("filetype plugin indent off")
assert(vim.g.did_load_ftplugin == nil)
require("config")
assert(vim.g.did_load_ftplugin == 1, "config must enable filetype plugins")

local buf = vim.api.nvim_create_buf(true, true)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "# Update ─────",
  "## example.nvim",
  "Path:     /tmp/example.nvim",
  "> abc123 │ feat: example change",
  "< def456 │ removed change",
})
vim.bo[buf].modifiable = false
vim.bo[buf].buftype = "acwrite"
vim.bo[buf].filetype = "nvim-pack"

local ns = vim.api.nvim_get_namespaces()["nvim.pack.confirm"]
assert(ns, "native pack confirmation highlighter did not run")
local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
local groups = {}
for _, mark in ipairs(marks) do
  groups[mark[4].hl_group] = true
end
for _, group in ipairs({ "DiagnosticWarn", "DiagnosticInfo", "Added", "Removed" }) do
  assert(groups[group], "missing native pack highlight: " .. group)
end
assert(vim.fn.maparg("]]", "n", false, true).buffer == 1,
  "native pack navigation mappings did not load")
vim.api.nvim_buf_delete(buf, { force = true })
print("tests/highlighting.lua: all tests passed")
