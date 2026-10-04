local root = vim.fn.getcwd()
local files = { root .. "/init.lua" }
for _, directory in ipairs({ "lua", "after", "tests" }) do
  local base = root .. "/" .. directory
  if vim.fn.isdirectory(base) == 1 then
    for name, kind in vim.fs.dir(base, { depth = math.huge }) do
      if kind == "file" and name:match("%.lua$") then
        files[#files + 1] = base .. "/" .. name
      end
    end
  end
end
for _, file in ipairs(files) do
  assert(loadfile(file))
end
print("Lua syntax OK: " .. #files .. " files")
