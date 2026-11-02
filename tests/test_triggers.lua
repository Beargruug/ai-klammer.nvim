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

-- The joke trigger is the one knob people will want turned down, so it hangs
-- off annoyance instead of a switch of its own.
local idle = require("ai_klammer.triggers.idle")
local quiet = require("ai_klammer.config").setup({ annoyance = 0 })
assert(quiet.joke_chance == 0, "annoyance 0 makes no jokes")
assert(require("ai_klammer.config").setup({ annoyance = 3 }).joke_chance > config.joke_chance, "3 makes more than 2")

local fired
idle.check(buf, quiet, function(count)
  fired = count
end)
assert(fired == nil, "and the check agrees, whatever the dice say")

local real_random = math.random
math.random = function()
  return 0
end
idle.check(buf, config, function(count)
  fired = count
end)
math.random = real_random
assert(fired, "a low roll is a joke")

-- Jokes must not win the shared cooldown off the triggers that have something
-- real to say, so they ask for a much longer one of their own.
assert(idle.cooldown > require("ai_klammer.config").cooldowns[1], "jokes are rarer than the chattiest trigger")

-- No question behind it means no buttons: nothing to say yes to.
assert(require("ai_klammer.ai").questions[idle.name] == nil, "there is nothing to ask about a joke")

local bubble = require("ai_klammer.ui.bubble")
local before = vim.api.nvim_get_current_win()
local win = triggers.fire(idle.name, 1, config)
assert(bubble.is_open(), "it still says it")
assert(vim.api.nvim_get_current_win() == before, "and never takes the cursor")
local shown = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
assert(not vim.tbl_contains(shown, bubble.buttons.en.line), "but offers no buttons:\n" .. table.concat(shown, "\n"))
require("ai_klammer").hide()

-- What a yes sends. ai.run is stubbed: this is about the question, not the answer.
local ai = require("ai_klammer.ai")
local real_run = ai.run
local sent
ai.run = function(question, range)
  sent = { question = question, range = range }
end
local function yes()
  vim.api.nvim_feedkeys("y", "x", false)
  vim.wait(100, function()
    return sent ~= nil
  end)
end

-- The regex, with a few lines around it, not the whole function it sits in.
local code = vim.api.nvim_create_buf(true, false)
local body = {}
for index = 1, 20 do
  body[index] = "  local x" .. index .. " = 1"
end
body[10] = [[  local date = "^(%d%d%d%d)-(%d%d)-(%d%d)$"]]
vim.api.nvim_buf_set_lines(code, 0, -1, false, body)
vim.api.nvim_set_current_buf(code)
vim.api.nvim_win_set_cursor(0, { 10, 0 })
sent = nil
triggers.fire("regex", 9, config)
yes()
assert(sent, "yes asks")
assert(vim.deep_equal(sent.range, { 7, 13 }), "the lines around the regex: " .. vim.inspect(sent.range))
assert(sent.question:find("line 10", 1, true), "and which one is meant: " .. sent.question)

-- Diagnostics are read from the buffer that was counted, not whichever is current.
local ns = vim.api.nvim_create_namespace("test_triggers")
local broken = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(broken, 0, -1, false, { "oops" })
vim.diagnostic.set(ns, broken, {
  { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "undefined global oops" },
})
sent = nil
triggers.fire("diagnostics", 1, config, broken)
yes()
assert(sent and sent.question:find("undefined global oops", 1, true), "the counted buffer's errors are spelled out")

ai.run = real_run
require("ai_klammer").hide()

print("ok")
