vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local state = require("ai_klammer.state")
state.path = vim.fn.tempname() .. "/ai_klammer.json"
local memory = require("ai_klammer.memory")
local quips = require("ai_klammer.quips")

local hour, day = 3600, 86400
local t0 = os.time({ year = 2026, month = 11, day = 4, hour = 10 })
local function new_session(now)
  memory.session = nil -- what a fresh Neovim starts with
  return memory.start(now)
end

-- The very first time it meets you.
local seen = new_session(t0)
assert(seen.sessions == 1 and seen.gap == nil, "nothing to remember yet")
assert(memory.occasion(seen) == "first_meeting", "so it introduces itself")
assert(memory.start(t0 + 60) == seen, "setup() twice in one Neovim is still one session")

-- Quitting is the last time it saw you, not starting.
memory.touch(t0 + 2 * hour)
seen = new_session(t0 + 2 * hour + 5 * 60)
assert(seen.sessions == 2 and seen.gap == 5 * 60, "five minutes since you quit")
assert(memory.occasion(seen, 0) == "quick_restart", "back that quickly is the config again")
assert(memory.occasion(seen, 0.99) == nil, "but only half the time, or it gets old")

seen = new_session(t0 + 6 * day)
local key, count = memory.occasion(seen)
assert(key == "back_after" and count == 5, "five whole days away: " .. tostring(key) .. " " .. tostring(count))
seen = new_session(t0 + 6 * day + hour)
assert(memory.occasion(seen, 0.99) == nil, "an hour is nothing worth mentioning")

-- Round numbers of sessions, over anything else.
state.update(function(data)
  data.memory.sessions = 9
end)
seen = new_session(t0 + 20 * day)
key, count = memory.occasion(seen)
assert(key == "milestone" and count == 10, "the tenth session beats twelve days away")

for _, n in ipairs({ 10, 25, 50, 100, 300 }) do
  assert(memory.milestone(n), n .. " is a round number")
end
for _, n in ipairs({ 1, 9, 11, 26, 150 }) do
  assert(not memory.milestone(n), n .. " is not")
end

-- Every no is counted, and the count survives a restart.
local before = memory.noes()
assert(memory.said_no() == before + 1, "one more no")
assert(state.memory().noes == before + 1, "written down")

-- A greeting is never the one from last time, even across restarts.
quips.moment_chance = 0
local en = require("ai_klammer.quips.en")
seen = new_session(t0 + 20 * day + hour)
for _, last in ipairs(en.greeting) do
  state.update(function(data)
    data.memory.last_greeting = last
  end)
  local greeting = memory.greeting(seen, "en", nil, 0.99)
  assert(greeting ~= last, "said the same greeting twice: " .. last)
  assert(state.memory().last_greeting == greeting, "and remembers the new one")
end
assert(memory.greeting({ sessions = 1 }, "de"), "the first meeting has German quips too")

-- Each memory quip exists in both languages.
for _, language in ipairs({ "en", "de" }) do
  local set = require("ai_klammer.quips." .. language)
  for _, list in ipairs({ "first_meeting", "milestone", "back_after", "quick_restart", "noes" }) do
    assert(set[list] and #set[list] >= 4, language .. "/" .. list .. " needs at least 4 quips")
  end
end

-- Another Neovim saved an answer since this one read the file: writing the
-- memory must not put the stale copy back over it.
local file = vim.json.decode(table.concat(vim.fn.readfile(state.path), "\n"))
file.consent = true
file.never = { git = true }
vim.fn.writefile({ vim.json.encode(file) }, state.path)
memory.touch(t0 + 30 * day)
assert(state.consent() == true, "the other Neovim's consent survives")
assert(state.is_never("git"), "and so does its never again")

-- :Klammer reset is about silencing, not about forgetting who you are.
local sessions = state.memory().sessions
state.reset()
assert(not state.is_never("git") and state.consent() == nil, "reset forgets the answers")
assert(state.memory().sessions == sessions, "but not how long you have known each other")

-- Saying no to a trigger for the tenth time gets a remark of its own.
state.update(function(data)
  data.memory.noes = 9
end)
local config = require("ai_klammer.config").setup({ language = "en" })
local bubble = require("ai_klammer.ui.bubble")
require("ai_klammer.triggers").fire("regex", 5, config)
vim.api.nvim_feedkeys("n", "x", false)
vim.wait(100)
assert(bubble.is_open(), "a remark about the count")
local shown = {}
for _, win in ipairs(vim.api.nvim_list_wins()) do
  shown[#shown + 1] = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), " ")
end
shown = table.concat(shown, " | ")
assert(shown:find("10", 1, true), "with the number in it: " .. shown)
require("ai_klammer").hide()

print("ok")
