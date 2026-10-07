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

print("ok")
