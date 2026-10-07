vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local regex = require("ai_klammer.triggers.regex")
local git = require("ai_klammer.triggers.git")
local triggers = require("ai_klammer.triggers")

assert(regex.looks_like_regex([[local ok = line:match("^%s*(%w+)%s*=%s*(.+)$")]]), "Lua pattern should trip it")
assert(regex.looks_like_regex([[const re = /^[a-z0-9._%+-]+@[a-z0-9.-]+$/i]]), "slash literal should trip it")
assert(not regex.looks_like_regex([[local msg = "hello (world)"]]), "plain prose should not")
assert(not regex.looks_like_regex([[if (a[0] + b[1]) then return c(d) end]]), "code without literals should not")

assert(git.changed_lines(" 3 files changed, 412 insertions(+), 18 deletions(-)\n") == 430, "insertions + deletions")
assert(git.changed_lines("") == 0, "no diff is zero lines")

local config = require("ai_klammer.config").setup()
local buf = vim.api.nvim_create_buf(false, true)
assert(triggers.ignored(buf, config), "scratch buffers are ignored")
vim.bo[buf].buftype = ""
vim.bo[buf].filetype = "help"
assert(triggers.ignored(buf, config), "blacklisted filetypes are ignored")
vim.bo[buf].filetype = "lua"
assert(not triggers.ignored(buf, config), "normal buffers are fair game")

assert(require("ai_klammer.config").setup({ annoyance = 0 }).cooldown == math.huge, "annoyance 0 never fires")
assert(require("ai_klammer.config").setup({ annoyance = 3 }).cooldown == 60, "annoyance 3 is chatty")

print("ok")
