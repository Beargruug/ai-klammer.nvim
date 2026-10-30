vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local avatar = require("ai_klammer.ui.avatar")
local bubble = require("ai_klammer.ui.bubble")

local followed_up = false
bubble.show("Would you like help?", {
  language = "en",
  mood = "thinking",
  buttons = true,
  on_yes = function()
    followed_up = true
    bubble.show("Not yet.", { language = "en" })
  end,
})
assert(bubble.is_open(), "bubble should open")
assert(avatar.is_open(), "the Klammer comes up with the bubble")
assert(avatar.mood() == "thinking", "the bubble sets the mood")

-- Regression: the WinLeave handler used to close the bubble that "yes" had just opened.
vim.api.nvim_feedkeys("y", "x", false)
vim.wait(100)
assert(followed_up, "yes should run its callback")
assert(bubble.is_open(), "the follow-up bubble must survive")
assert(avatar.is_open(), "the Klammer stays for the follow-up")

vim.api.nvim_feedkeys("q", "x", false)
vim.wait(100)
assert(not bubble.is_open(), "q dismisses the bubble")
assert(avatar.is_open(), "the Klammer stays after the bubble is answered")
assert(avatar.mood() == "neutral", "the mood resets with the bubble")

require("ai_klammer").hide()
assert(not avatar.is_open(), ":Klammer hide is the only way out")

-- The greeting must never take the cursor and must clear itself.
local editor = vim.api.nvim_get_current_win()
bubble.show("Hello.", { language = "en", focus = false, timeout = 150 })
assert(bubble.is_open(), "greeting should open")
assert(vim.api.nvim_get_current_win() == editor, "greeting must not steal the cursor")
vim.wait(600, function()
  return not bubble.is_open()
end)
assert(not bubble.is_open(), "timeout should dismiss the greeting")
assert(avatar.is_open(), "the Klammer stays once the greeting fades")

-- Every bubble gets a fresh scratch buffer; a closed one must not linger in :ls!.
local before = #vim.api.nvim_list_bufs()
for _ = 1, 5 do
  bubble.show("Again.", { language = "en", focus = false })
  bubble.close()
end
assert(#vim.api.nvim_list_bufs() == before, "closed bubbles leave no buffers behind")

-- A quip is typed in, not dropped in. The window opens at its final size so
-- nothing jumps, and the buttons come once the text is there.
local function text(win)
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
end
local quip = "Schön, dich zu sehen. Ich habe in deiner Abwesenheit alles zusammengehalten."
local typed = bubble.show(quip, { language = "de", buttons = true, animate = true, focus = false })
local final = vim.api.nvim_win_get_config(typed)
local first = text(typed)
assert(#first[1] < 10, "it starts out nearly empty: " .. first[1])
assert(first[#first] == "", "no buttons yet")

local frames = {}
vim.wait(3000, function()
  local cfg = vim.api.nvim_win_get_config(typed)
  assert(cfg.width == final.width and cfg.height == final.height, "the window does not change size while typing")
  local now = text(typed)
  frames[#frames + 1] = now
  return now[#now] == bubble.buttons.de.line
end)
local done = text(typed)
assert(done[#done] == bubble.buttons.de.line, "the buttons, once the text is done")
assert(table.concat(done, " "):find("zusammengehalten.", 1, true), "and all of the text")
local partial = 0
for _, frame in ipairs(frames) do
  for index, line in ipairs(frame) do
    -- Cut at a character, never in the middle of the bytes of an ö.
    local cut = vim.fn.strcharpart(done[index], 0, vim.fn.strchars(line))
    assert(cut == line, ("line %d is not a prefix of %q: %q"):format(index, done[index], line))
  end
  if frame[1] ~= "" and frame[1] ~= done[1] then
    partial = partial + 1
  end
end
assert(partial > 0, "there was something in between")

-- Anything that writes the bubble itself stops the typing for good.
local interrupted = bubble.show(quip, { language = "de", animate = true, focus = false })
bubble.update("Kurz.")
vim.wait(300)
assert(text(interrupted)[1] == "Kurz.", "the typewriter does not write over it: " .. text(interrupted)[1])
bubble.close()

-- Fading bubbles get the typing time on top, or long quips vanish half-read.
local slow = bubble.show(("lang "):rep(40), { language = "de", animate = true, focus = false, timeout = 100 })
vim.wait(300)
assert(vim.api.nvim_win_is_valid(slow), "still open: the timeout starts after the typing")
bubble.close()

print("ok")
