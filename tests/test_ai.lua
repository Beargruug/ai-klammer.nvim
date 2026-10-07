vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local bubble = require("ai_klammer.ui.bubble")
local context = require("ai_klammer.context.buffer")
-- Anthropic speaks SSE: "data: {...}" lines, "event:" lines to skip, and a bare
-- JSON body when the request never becomes a stream.
local anthropic = require("ai_klammer.providers.anthropic")
local events, tail = anthropic.parse(
  'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"It "}}\ndata: {"ty'
)
assert(#events == 1 and events[1].content == "It ", "only the data line carries text")
assert(tail == 'data: {"ty', "the half line waits for the next read")

-- Streams arrive split at arbitrary byte boundaries, never on whole lines.
local rejoined = anthropic.parse(tail .. 'pe":"content_block_delta","delta":{"text":"lo"}}\n')
assert(rejoined[1].content == "lo", "the rejoined line parses")
assert(#anthropic.parse("not json at all\n") == 0, "garbage is skipped, not thrown")

events = anthropic.parse('data: {"type":"message_stop"}\n')
assert(events[1].done and events[1].content == "", "message_stop ends it without text")

events = anthropic.parse('{"type":"error","error":{"type":"not_found_error","message":"model: nope"}}\n')
assert(events[1].error == "model: nope", "a rejected request is not SSE and still has to come through")

assert(anthropic.key({ ai = {
  api_key = function()
    return "from-a-function"
  end,
} }) == "from-a-function", "a function key is called, so secrets can stay out of the config")

-- The claude CLI prints NDJSON and hides failures in the last line, not the exit code.
local claude = require("ai_klammer.providers.claude")
local cli, cli_tail = claude.parse(
  '{"type":"system","subtype":"init"}\n'
    .. '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"It "}}}\n'
    .. '{"type":"stream_ev'
)
assert(#cli == 2 and cli[1].content == "" and cli[2].content == "It ", "only deltas carry text")
assert(cli_tail == '{"type":"stream_ev', "the half line waits")

-- The full assistant message repeats the text; taking it too would double the answer.
cli = claude.parse('{"type":"assistant","message":{"content":[{"type":"text","text":"It "}]}}\n')
assert(cli[1].content == "", "the echoed assistant message is ignored")

cli = claude.parse('{"type":"result","subtype":"success","is_error":true,"result":"no such model"}\n')
assert(cli[1].done and cli[1].error == "no such model", "a failed result is an error despite subtype success")

cli = claude.parse('{"type":"result","subtype":"success","is_error":false,"result":"It "}\n')
assert(cli[1].done and cli[1].error == nil and cli[1].content == "", "a good result just ends the stream")

local config = require("ai_klammer.config").setup()

-- Bring your own provider: a table with a stream function is enough.
local ai = require("ai_klammer.ai")
assert(ai.resolve(config).stream == claude.stream, "a name resolves to a bundled module")
assert(ai.resolve({ ai = { provider = "nope" } }) == nil, "an unknown name resolves to nothing")

local mine = { stream = function() end }
assert(ai.resolve(require("ai_klammer.config").setup({ ai = { provider = mine } })).stream == mine.stream)

local bad = pcall(require("ai_klammer.config").setup, { ai = { provider = { model = "x" } } })
assert(not bad, "a table without stream is rejected at setup, not at the first question")

local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "local function outer()",
  "  return 1",
  "end",
  "",
  "local x = 2",
})
vim.bo[buf].filetype = "lua"

local selected = context.grab(buf, { 2, 3 }, config)
assert(selected.source == "selection" and selected.text == "  return 1\nend", "a range wins")

vim.api.nvim_win_set_cursor(0, { 2, 0 })
local enclosing = context.grab(buf, nil, config)
assert(enclosing.first == 1 and enclosing.last == 3, "no range falls back to the function")
assert(enclosing.source == "function", "and says so")

vim.api.nvim_win_set_cursor(0, { 5, 0 })
local nearby = context.grab(buf, nil, config)
assert(nearby.source == "nearby", "outside any function it grabs what is near the cursor")
assert(nearby.first == 1 and nearby.last == 5, "clamped to the buffer")

local empty, reason = context.grab(buf, { 4, 4 }, config)
assert(empty == nil and reason == "empty", "a blank selection is refused")

local big, why, count = context.grab(buf, { 1, 5 }, vim.tbl_deep_extend("force", config, { ai = { max_lines = 2 } }))
assert(big == nil and why == "too_big" and count == 5, "an oversized selection is refused with its size")

-- The bubble has to grow as an answer streams in, in place, without reopening.
local win = bubble.show("Let me unbend for a second...", { language = "en", focus = false })
local bubble_buf = vim.api.nvim_win_get_buf(win)
local height = vim.api.nvim_win_get_config(win).height

bubble.update(("word "):rep(60))
assert(bubble.is_open() and vim.api.nvim_win_get_buf(win) == bubble_buf, "same window, same buffer")
assert(#vim.api.nvim_buf_get_lines(bubble_buf, 0, -1, false) > 1, "long answers wrap")
assert(vim.api.nvim_win_get_config(win).height > height, "the bubble grew")
assert(vim.api.nvim_win_get_config(win).border ~= "none", "and kept its border")

bubble.update("short")
assert(vim.api.nvim_buf_get_lines(bubble_buf, 0, -1, false)[1] == "short", "the bubble shrinks again")
assert(vim.api.nvim_win_get_config(win).height == 1, "down to one line")

require("ai_klammer").hide()

print("ok")
