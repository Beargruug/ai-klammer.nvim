vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local avatar = require("ai_klammer.ui.avatar")

local win = avatar.show("neutral")
local function line(row)
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), row - 1, row, false)[1]
end
local function eyes()
  return line(avatar.eyes_row)
end
assert(eyes() == "◐  ◐ ", "it starts out looking at you")

-- A face blinks irregularly. A metronome does not count as alive.
local intervals = {}
for _ = 1, 50 do
  local ms = avatar.next_blink()
  assert(ms >= 2000 and ms <= 8000, "a blink is two to eight seconds away, not " .. ms)
  intervals[ms] = true
end
assert(vim.tbl_count(intervals) > 1, "and not the same interval every time")

-- The eyes follow the cursor across the editor, by thirds.
assert(avatar.gaze_for(5, 120) == "left", "left third")
assert(avatar.gaze_for(60, 120) == nil, "middle: straight at you")
assert(avatar.gaze_for(110, 120) == "right", "right third")
avatar.look("left")
assert(eyes() == "◐  ◐ ", "pupils to the left")
avatar.look("right")
assert(eyes() == "◑  ◑ ", "pupils to the right")

-- With ambiwidth=double the half circles take two cells each.
vim.o.ambiwidth = "double"
avatar.look(nil)
avatar.look("right")
assert(eyes() == "◑ ◑", "so one space between them keeps it five cells wide")
assert(vim.fn.strdisplaywidth(eyes()) == avatar.width, "and the wire in one piece")
avatar.set_mood("happy")
assert(eyes() == "^  ^ ", "ASCII faces stay as they are")
avatar.set_mood("neutral")
vim.o.ambiwidth = "single"
avatar.look(nil)

-- A mood outranks where it is looking.
avatar.look("left")
avatar.set_mood("thinking")
assert(eyes() == "o  o ", "thinking is thinking, wherever the cursor is")
avatar.set_mood("neutral")
assert(eyes() == "◐  ◐ ", "and the gaze comes back with the neutral mood")

-- A reaction passes over the face and is gone again.
avatar.react("happy", 50)
assert(eyes() == "^  ^ ", "a reaction shows at once")
vim.wait(500, function()
  return eyes() ~= "^  ^ "
end)
assert(eyes() == "◐  ◐ ", "then the face it had before")
avatar.look(nil)

-- It nods off, snores, and wakes with a start.
avatar.sleep()
assert(avatar.asleep() and eyes() == "-  - ", "eyes shut")
vim.wait(2500, function()
  return line(avatar.eyes_row - 3):find("Z") or line(avatar.eyes_row - 2):find("z")
end)
assert(line(avatar.eyes_row - 3):find("Z") or line(avatar.eyes_row - 2):find("z"), "a z drifts up above its head")
avatar.poke()
assert(not avatar.asleep(), "any keypress wakes it")
assert(eyes() == "O  O ", "startled")
assert(not line(avatar.eyes_row - 3):find("Z") and not line(avatar.eyes_row - 2):find("z"), "the snoring stops")

-- It hops when it has something to say: into the headroom above it and back.
vim.wait(1000) -- let the start of the wake-up pass
local top = avatar.eyes_row - 3
assert(line(top - 1):match("^%s*$"), "a free row above its head")
avatar.hop()
assert(line(top - 1) == " __  ", "up it goes")
assert(line(avatar.height):match("^%s*$"), "feet off the ground")
vim.wait(500, function()
  return line(top) == " __  "
end)
assert(line(top) == " __  " and line(top - 1):match("^%s*$"), "and back down")

-- Showing up for a bubble wakes it too.
avatar.sleep()
avatar.show("thinking")
assert(not avatar.asleep(), "a bubble needs a Klammer that is awake")

avatar.hide()
print("ok")
