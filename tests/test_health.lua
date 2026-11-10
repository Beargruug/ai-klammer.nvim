vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local state = require("ai_klammer.state")
state.path = vim.fn.tempname() .. "/ai_klammer.json"
require("ai_klammer").setup({ annoyance = 0 })

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
vim.fn.writefile({ "TOKEN=x" }, dir .. "/.env")
vim.fn.writefile({ "local a = 1" }, dir .. "/a.lua")

--- The report :checkhealth writes, run from `file`, the way you would.
local function report(file, mods)
  vim.cmd("silent! tabonly | silent! only | edit " .. vim.fn.fnameescape(file))
  vim.cmd((mods or "") .. " checkhealth ai_klammer")
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  vim.cmd("bwipeout!")
  return text
end

local warning = "is blocklisted, so the Klammer ignores it on purpose"
-- Regression: the check read the current buffer, which by then is the
-- report itself, so it never warned about the file you asked from.
for _, mods in ipairs({ "", "vertical", "tab" }) do
  assert(report(dir .. "/.env", mods):find(warning, 1, true), "a blocklisted file is named as one, mods: " .. mods)
end
assert(not report(dir .. "/a.lua"):find(warning, 1, true), "an ordinary file is not")

vim.fn.delete(dir, "rf")
print("ok")
