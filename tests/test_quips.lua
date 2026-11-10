vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local quips = require("ai_klammer.quips")

local set = require("ai_klammer.quips.en")
for _, trigger in ipairs({ "greeting", "idle", "regex", "git", "diagnostics" }) do
  assert(#set[trigger] >= 10, trigger .. " needs at least 10 quips")
  for _, quip in ipairs(set[trigger]) do
    assert(#quip > 0 and not quip:find("%%[^d]"), "bad format string: " .. quip)
  end
end

assert(quips.pick("regex"), "a trigger has its quips")
assert(quips.pick("nope") == nil, "unknown trigger has no quip")

local counted = quips.pick("git", 412)
assert(not counted:find("%%d"), "no raw placeholder should survive")

-- Moments: the clock and the calendar, never the code.
local function at(day, hour)
  return os.time({ year = 2026, month = 11, day = day, hour = hour })
end
local function has(list, key)
  return vim.tbl_contains(list, key)
end
quips.started = at(4, 13) -- the session began an hour before the usual test time
assert(has(quips.moments(at(4, 3)), "night"), "3 a.m. is night")
assert(has(quips.moments(at(4, 6)), "early"), "6 a.m. is early")
assert(#quips.moments(at(4, 14)) == 0, "a Wednesday afternoon is nothing special")
assert(has(quips.moments(at(2, 9)), "monday"), "Monday morning")
assert(not has(quips.moments(at(2, 15)), "monday"), "Monday afternoon is just a day")
assert(has(quips.moments(at(6, 16)), "friday"), "Friday afternoon")
assert(not has(quips.moments(at(6, 10)), "friday"), "Friday morning is still a workday")
assert(has(quips.moments(at(7, 14)), "weekend"), "Saturday")
assert(not has(quips.moments(at(4, 14), at(4, 13)), "long_session"), "an hour in is fine")
assert(has(quips.moments(at(4, 14), at(4, 11)), "long_session"), "three hours in is a long session")

-- Every moment and every filetype has its quips.
for _, moment in ipairs({ "night", "early", "monday", "friday", "weekend", "long_session" }) do
  assert(#set.moments[moment] >= 4, moment .. " needs at least 4 quips")
end
for filetype, list in pairs(set.filetypes) do
  assert(#list >= 2, "needs at least 2 for " .. filetype)
end
for _, list in pairs(vim.tbl_extend("error", set.moments, set.filetypes)) do
  for _, quip in ipairs(list) do
    assert(not quip:find("%%[^d]"), "bad format string: " .. quip)
  end
end

-- A moment wins only some of the time, so the generic quips still get a turn.
local en = require("ai_klammer.quips.en")
local function from(list, quip, count)
  for _, candidate in ipairs(list) do
    if candidate:format(count or 0) == quip then
      return true
    end
  end
  return false
end
local real_random = math.random
math.random = function(n)
  return n and real_random(n) or 0 -- low roll: take the moment
end
assert(from(en.filetypes.yaml, quips.remark("idle", "yaml", at(4, 14))), "the filetype is a moment")
assert(from(en.filetypes.typescript, quips.remark("idle", "typescriptreact", at(4, 14))), "tsx is TypeScript")
for alias, filetype in pairs(quips.same_as) do
  assert(en.filetypes[filetype], alias .. " points at " .. filetype .. ", which has no quips")
end
local three_hours = quips.remark("idle", nil, at(4, 14), at(4, 11))
assert(from(en.moments.long_session, three_hours, 3), "the session length is filled in: " .. three_hours)
math.random = function(n)
  return n and real_random(n) or 0.99 -- high roll: the generic list
end
assert(from(en.idle, quips.remark("idle", "yaml", at(4, 14))), "a high roll is the plain quip")
math.random = real_random

-- Like a deck of cards: every quip once before any of them twice.
local deck = { "a", "b", "c", "d", "e" }
local dealt = {}
for _ = 1, #deck do
  local card = quips.draw(deck)
  assert(not dealt[card], "dealt twice before the deck ran out: " .. card)
  dealt[card] = true
end
-- And a fresh deck never opens with the card the last one ended on.
local previous
for _ = 1, 500 do
  local card = quips.draw(deck)
  assert(card ~= previous, "the same quip twice in a row: " .. card)
  previous = card
end
assert(quips.draw({ "only" }) == "only" and quips.draw({ "only" }) == "only", "a deck of one still deals")

-- pick() goes through the deck too, so a whole list is said before a repeat.
local said = {}
for _ = 1, #en.diagnostics do
  local quip = quips.pick("diagnostics", 7)
  assert(not said[quip], "repeated before the list ran out: " .. quip)
  said[quip] = true
end
assert(quips.remark("idle", "unknown_ft", at(4, 14)), "nothing special still says something")
assert(quips.remark("greeting", "lua", at(4, 3)), "greetings get moments too")

print("ok")
