vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local avatar = require("ai_klammer.ui.avatar")
local bubble = require("ai_klammer.ui.bubble")

local followed_up = false
bubble.show("Would you like help?", {
  mood = "thinking",
  buttons = true,
  on_yes = function()
    followed_up = true
    bubble.show("Not yet.", {})
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
bubble.show("Hello.", { focus = false, timeout = 150 })
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
  bubble.show("Again.", { focus = false })
  bubble.close()
end
assert(#vim.api.nvim_list_bufs() == before, "closed bubbles leave no buffers behind")

-- Highlighted like markdown, without markdown's LSPs and ftplugins.
local markdown_attached = false
local watch = vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    markdown_attached = true
  end,
})
local styled = bubble.show("Some `code`.", { focus = false })
local styled_buf = vim.api.nvim_win_get_buf(styled)
assert(not markdown_attached, "no FileType markdown for a bubble")
assert(
  vim.treesitter.highlighter.active[styled_buf] or vim.bo[styled_buf].syntax == "markdown",
  "but it still looks like markdown"
)
vim.api.nvim_del_autocmd(watch)
bubble.close()

-- A quip is typed in, not dropped in. The window opens at its final size so
-- nothing jumps, and the buttons come once the text is there.
local function text(win)
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
end
-- Accents on purpose: the typing counts characters, so é is never cut in half.
local quip = "Nice to see you. I held everything together while you were away, crème brûlée included."
local typed = bubble.show(quip, { buttons = true, animate = true, focus = false })
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
  return now[#now] == bubble.buttons.line
end)
local done = text(typed)
assert(done[#done] == bubble.buttons.line, "the buttons, once the text is done")
assert(table.concat(done, " "):find("brûlée included.", 1, true), "and all of the text")
local partial = 0
for _, frame in ipairs(frames) do
  for index, line in ipairs(frame) do
    -- Cut at a character, never in the middle of the bytes of an é.
    local cut = vim.fn.strcharpart(done[index], 0, vim.fn.strchars(line))
    assert(cut == line, ("line %d is not a prefix of %q: %q"):format(index, done[index], line))
  end
  if frame[1] ~= "" and frame[1] ~= done[1] then
    partial = partial + 1
  end
end
assert(partial > 0, "there was something in between")

-- Anything that writes the bubble itself stops the typing for good.
local interrupted = bubble.show(quip, { animate = true, focus = false })
bubble.update("Short.")
vim.wait(300)
assert(text(interrupted)[1] == "Short.", "the typewriter does not write over it: " .. text(interrupted)[1])
bubble.close()

-- A streaming answer follows its newest line, unless you went in to scroll.
local long_answer = ("word "):rep(400)
local streaming = bubble.show("...", { focus = false })
bubble.update(long_answer)
local bottom = vim.api.nvim_win_get_cursor(streaming)[1]
assert(bottom > 1, "unfocused, it shows the newest line")
assert(bubble.focus(), "focus goes in")
vim.api.nvim_win_set_cursor(streaming, { 1, 0 })
bubble.update(long_answer .. "more")
assert(vim.api.nvim_win_get_cursor(streaming)[1] == 1, "focused, the next chunk leaves the cursor where you put it")
bubble.close()
assert(vim.api.nvim_get_current_win() == editor, "closing puts the cursor back")

-- Leaving an answer you went into yourself leaves it open, still streaming.
local cancelled = false
local answer = bubble.show("Half an answer", {
  focus = false,
  on_close = function()
    cancelled = true
  end,
})
bubble.focus()
vim.api.nvim_set_current_win(editor)
vim.wait(50)
assert(vim.api.nvim_win_is_valid(answer), "walking out of a focused answer keeps it")
assert(not cancelled, "and the request behind it")
bubble.close()
assert(cancelled, "closing it still cancels")

-- A bubble that took the cursor is waiting for a key; walking away answers it.
local asking = bubble.show("Would you like help?", { buttons = true })
assert(vim.api.nvim_get_current_win() == asking, "it takes the cursor")
vim.api.nvim_set_current_win(editor)
vim.wait(50)
assert(not vim.api.nvim_win_is_valid(asking), "leaving it closes it")

-- Fading bubbles get the typing time on top, or long quips vanish half-read.
local slow = bubble.show(("lang "):rep(40), { animate = true, focus = false, timeout = 100 })
vim.wait(300)
assert(vim.api.nvim_win_is_valid(slow), "still open: the timeout starts after the typing")
bubble.close()

-- fade closes the bubble it was given, not one that opened since, and
-- waits while you are in it.
local fading = bubble.show("Going.", { focus = false })
bubble.fade(fading, 50)
vim.wait(150)
assert(not vim.api.nvim_win_is_valid(fading), "it fades")

local old = bubble.show("Old.", { focus = false })
bubble.fade(old, 50)
local new = bubble.show("New.", { focus = false })
vim.wait(150)
assert(vim.api.nvim_win_is_valid(new), "a newer bubble is left alone")

bubble.fade(new, 50)
bubble.focus()
vim.wait(150)
assert(vim.api.nvim_win_is_valid(new), "not while you are reading it")
vim.api.nvim_set_current_win(editor)
vim.wait(150, function()
  return not vim.api.nvim_win_is_valid(new)
end)
assert(not vim.api.nvim_win_is_valid(new), "and once you leave, it goes")

-- Wrapping counts display cells, not bytes: "ä" is two bytes and one column.
local umlauts = bubble.wrap("äää äää äää", 11)
assert(#umlauts == 1, "eleven columns fit on one line: " .. vim.inspect(umlauts))

-- Code in an answer keeps its indentation and its line breaks.
local answer = bubble.wrap("Like this:\n```lua\nif x then\n  return 1\nend\n```\nand    more prose", 46)
assert(
  vim.deep_equal(answer, { "Like this:", "```lua", "if x then", "  return 1", "end", "```", "and more prose" }),
  "fenced code is left alone, prose around it is reflowed: " .. vim.inspect(answer)
)
assert(bubble.wrap("    indented code", 46)[1] == "    indented code", "indented lines are code too")

-- The bubble follows the Klammer when the editor is resized.
local columns = vim.o.columns
local resized = bubble.show("Still here.", { focus = false })
local before_col = vim.api.nvim_win_get_config(resized).col
vim.o.columns = columns - 10
vim.api.nvim_exec_autocmds("VimResized", {})
assert(vim.api.nvim_win_get_config(resized).col == before_col - 10, "moved left with the edge")
vim.o.columns = columns
bubble.close()

print("ok")
