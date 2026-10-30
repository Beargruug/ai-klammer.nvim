vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local quips = require("ai_klammer.quips")

for _, language in ipairs({ "en", "de" }) do
  local set = require("ai_klammer.quips." .. language)
  for _, trigger in ipairs({ "greeting", "idle", "regex", "git", "diagnostics" }) do
    assert(#set[trigger] >= 10, language .. "/" .. trigger .. " needs at least 10 quips")
    for _, quip in ipairs(set[trigger]) do
      assert(#quip > 0 and not quip:find("%%[^d]"), "bad format string: " .. quip)
    end
  end
end

assert(quips.pick("regex", "klingon"), "unknown language falls back to English")
assert(quips.pick("nope", "en") == nil, "unknown trigger has no quip")

local counted = quips.pick("git", "en", 412)
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

-- Every moment and every filetype has its quips, in both languages.
for _, language in ipairs({ "en", "de" }) do
  local set = require("ai_klammer.quips." .. language)
  for _, moment in ipairs({ "night", "early", "monday", "friday", "weekend", "long_session" }) do
    assert(#set.moments[moment] >= 4, language .. "/" .. moment .. " needs at least 4 quips")
  end
  for filetype, list in pairs(require("ai_klammer.quips.en").filetypes) do
    assert(set.filetypes[filetype] and #set.filetypes[filetype] >= 2, language .. " needs quips for " .. filetype)
    assert(#list >= 2, "en needs at least 2 for " .. filetype)
  end
  for _, list in pairs(vim.tbl_extend("error", set.moments, set.filetypes)) do
    for _, quip in ipairs(list) do
      assert(not quip:find("%%[^d]"), "bad format string: " .. quip)
    end
  end
end

-- A moment wins only some of the time, so the generic quips still get a turn.
local en = require("ai_klammer.quips.en")
local real_random = math.random
math.random = function(n)
  return n and 1 or 0 -- low roll: take the moment, first of every list
end
assert(quips.remark("idle", "en", "yaml", at(4, 14)) == en.filetypes.yaml[1], "the filetype is a moment")
assert(quips.remark("idle", "en", "typescriptreact", at(4, 14)) == en.filetypes.typescript[1], "tsx is TypeScript")
for alias, filetype in pairs(quips.same_as) do
  assert(en.filetypes[filetype], alias .. " points at " .. filetype .. ", which has no quips")
end
local three_hours = quips.remark("idle", "en", nil, at(4, 14), at(4, 11))
assert(three_hours == en.moments.long_session[1]:format(3), "the session length is filled in: " .. three_hours)
math.random = function(n)
  return n and 1 or 0.99 -- high roll: the generic list
end
assert(quips.remark("idle", "en", "yaml", at(4, 14)) == en.idle[1], "a high roll is the plain quip")
math.random = real_random
assert(quips.remark("idle", "en", "unknown_ft", at(4, 14)), "nothing special still says something")
assert(quips.remark("greeting", "de", "lua", at(4, 3)), "greetings get moments too")

print("ok")
