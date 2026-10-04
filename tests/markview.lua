vim.opt.runtimepath:prepend(vim.fn.getcwd())
local spec = require("plugins.markview")
assert(spec[1] == "OXY2DEV/markview.nvim" and spec.lazy == false)
assert(vim.tbl_contains(spec.dependencies, "saghen/blink.cmp"))
assert(vim.tbl_contains(spec.dependencies, "nvim-tree/nvim-web-devicons"))
assert(spec.opts.preview.map_gx == false)
assert(spec.opts.preview.icon_provider == "devicons")
assert(#spec.opts.preview.ignore_buftypes == 0)
assert(vim.tbl_contains(spec.opts.preview.modes, "i"))
assert(vim.tbl_contains(spec.opts.preview.hybrid_modes, "i"))

local calls = {}
for _, module in ipairs({
	"markview", "markview.integrations", "markview.extras.editor",
	"markview.extras.headings", "markview.extras.checkboxes",
}) do
	package.preload[module] = function()
		return { setup = function(opts) calls[module] = opts or true end }
	end
end
spec.config({}, spec.opts)
assert(calls.markview == spec.opts)
assert(calls["markview.integrations"])
assert(calls["markview.extras.editor"])
assert(calls["markview.extras.headings"])
assert(calls["markview.extras.checkboxes"].default == "x")

local seen = {}
for _, key in ipairs(spec.keys) do
	assert(key[1]:match("^<leader>m"), "Markview mapping escapes its namespace")
	assert(not seen[key[1]], "Duplicate Markview mapping")
	seen[key[1]] = true
	assert(vim.deep_equal(key.ft, spec.opts.preview.filetypes), "Mapping is not scoped to Markdown")
	assert(key.mode == nil or key.mode == "n", "Extras require Normal mode")
end
local groups = require("plugins.which-key").opts.spec
assert(vim.iter(groups):any(function(group)
	return group[1] == "<leader>m" and group.group == "markdown"
end))
print("tests/markview.lua: configuration, integrations, extras and mappings passed")
