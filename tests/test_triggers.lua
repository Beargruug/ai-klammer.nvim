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
ai.run = function(question, range, _, from)
  sent = { question = question, range = range, buf = from }
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
local lines = {}
for index = 1, 60 do
  lines[index] = "local y" .. index .. " = 1"
end
vim.api.nvim_buf_set_lines(broken, 0, -1, false, lines)
vim.diagnostic.set(ns, broken, {
  { lnum = 29, col = 0, severity = vim.diagnostic.severity.ERROR, message = "undefined global later" },
  { lnum = 19, col = 0, severity = vim.diagnostic.severity.ERROR, message = "undefined global oops" },
})
sent = nil
-- The cursor sits in another buffer altogether, as after :wa.
triggers.fire("diagnostics", 2, config, broken)
yes()
assert(sent and sent.question:find("undefined global oops", 1, true), "the counted buffer's errors are spelled out")
assert(sent.question:find("line 20: undefined global oops", 1, true), "with their lines: " .. sent.question)
-- Regression: a yes sent the code around the cursor, wherever that was, and
-- not the lines the errors are on.
assert(sent.buf == broken, "the code comes from the counted buffer, not the current one")
assert(vim.deep_equal(sent.range, { 17, 33 }), "the lines around the errors: " .. vim.inspect(sent.range))

-- Errors too far apart to send together: the first one, and as much after it as fits.
vim.diagnostic.set(ns, broken, {
  { lnum = 9, col = 0, severity = vim.diagnostic.severity.ERROR, message = "early" },
  { lnum = 59, col = 0, severity = vim.diagnostic.severity.ERROR, message = "late" },
})
sent = nil
triggers.fire("diagnostics", 2, vim.tbl_deep_extend("force", config, { ai = { max_lines = 20 } }), broken)
yes()
assert(
  vim.deep_equal(sent.range, { 7, 26 }),
  "capped at ai.max_lines from the first error: " .. vim.inspect(sent.range)
)
assert(sent.question:find("line 60: late", 1, true), "the late one is still named")
vim.diagnostic.reset(ns, broken)

-- The git trigger's yes asks about the diff it counted, not the code under the cursor.
local real_changes = ai.changes
ai.changes = function(question, from)
  sent = { question = question, buf = from }
end
sent = nil
triggers.fire("git", 400, config, code)
yes()
assert(sent and sent.buf == code, "a git yes goes to ai.changes, with the buffer that was saved")
ai.changes = real_changes

ai.run = real_run
require("ai_klammer").hide()

-- The regex check reads the buffer that fired, and only while it is current.
vim.api.nvim_set_current_buf(code)
vim.api.nvim_win_set_cursor(0, { 10, 0 })
local counted
regex.check(code, config, function(count)
  counted = count
end)
assert(counted, "the regex under the cursor counts")
regex.check(vim.api.nvim_create_buf(true, false), config, function(count)
  counted = count
end)
assert(counted == nil, "a buffer you have left is not read through the current one")

-- A burst of events runs the checks once, after the debounce.
local runs = 0
local real_checks = triggers.checks
triggers.checks = {
  {
    name = "spy",
    events = { "CursorHold" },
    check = function()
      runs = runs + 1
    end,
  },
}
-- No cooldown: the triggers above have used up the shared one.
triggers.setup(vim.tbl_extend("force", config, { cooldown = 0 }))
for _ = 1, 5 do
  vim.api.nvim_exec_autocmds("CursorHold", { buffer = code })
end
vim.wait(600, function()
  return runs > 0
end)
vim.wait(100)
assert(runs == 1, "five quick events, one run: " .. runs)

-- Regression: with 'updatetime' under the debounce (kickstart.nvim sets 250),
-- the CursorHold right after :w replaced the pending BufWritePost, so the git
-- trigger never saw a single save.
local seen = {}
local function spy(name, event)
  return {
    name = name,
    events = { event },
    check = function()
      seen[name] = true
    end,
  }
end
triggers.checks = { spy("on_write", "BufWritePost"), spy("on_hold", "CursorHold") }
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = code })
vim.api.nvim_exec_autocmds("CursorHold", { buffer = code })
vim.wait(600, function()
  return seen.on_write and seen.on_hold
end)
assert(seen.on_hold, "the CursorHold still reaches its checks")
assert(seen.on_write, "and does not swallow the BufWritePost before it")
triggers.checks = real_checks
vim.api.nvim_clear_autocmds({ group = "AiKlammer" })

-- git.diff against a real repository: every changed file except the blocked ones.
local repo = vim.fn.tempname()
vim.fn.mkdir(repo, "p")
local function sh(...)
  local result = vim.system({ ... }, { cwd = repo, text = true }):wait()
  assert(result.code == 0, table.concat({ ... }, " ") .. ": " .. (result.stderr or ""))
end
vim.fn.writefile({ "local a = 1" }, repo .. "/a.lua")
vim.fn.writefile({ "TOKEN=old" }, repo .. "/.env")
sh("git", "init", "-q")
sh("git", "add", ".")
sh("git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
vim.fn.writefile({ "local a = 2" }, repo .. "/a.lua")
vim.fn.writefile({ "TOKEN=new" }, repo .. "/.env")

local diff, finished
git.diff(repo, function(path)
  return require("ai_klammer.context.secrets").blocked(path, config)
end, function(result)
  diff, finished = result, true
end)
vim.wait(5000, function()
  return finished
end)
assert(diff and diff:find("+local a = 2", 1, true), "the changed file is in the diff:\n" .. tostring(diff))
assert(not diff:find("TOKEN", 1, true), "the blocked one is not, not even its name")
assert(not diff:find(".env", 1, true), "not even in the --stat header")

vim.fn.writefile({ "local a = 1" }, repo .. "/a.lua")
diff, finished = "unset", false
git.diff(repo, function(path)
  return require("ai_klammer.context.secrets").blocked(path, config)
end, function(result)
  diff, finished = result, true
end)
vim.wait(5000, function()
  return finished
end)
assert(diff == nil, "only blocked files changed means nothing to show")
vim.fn.delete(repo, "rf")

print("ok")
