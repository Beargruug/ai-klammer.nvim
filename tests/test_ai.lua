vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

-- The consent tests below reset and refuse: not in the real state file, where
-- that would wipe the answers of whoever runs the tests.
require("ai_klammer.state").path = vim.fn.tempname() .. "/ai_klammer.json"

local bubble = require("ai_klammer.ui.bubble")
local context = require("ai_klammer.context.buffer")

-- One line splitter for all three providers: "data: " prefixes come off,
-- "event:" lines and half-written tails drop out because they do not decode.
local shared = require("ai_klammer.providers.shared")
local objects, tail = shared.events('event: ping\ndata: {"a":1}\n{"b":2}\ndata: {"c')
assert(#objects == 2 and objects[1].a == 1 and objects[2].b == 2, "SSE and bare NDJSON both decode")
assert(tail == 'data: {"c', "the half line waits for the next read")
assert(#shared.events("not json at all\ndata: [DONE]\n") == 0, "garbage and the DONE sentinel are skipped")

local anthropic = require("ai_klammer.providers.anthropic")
local events = anthropic.parse(
  'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"type":"text_delta","text":"It "}}\n'
)
assert(#events == 1 and events[1].content == "It ", "only the data line carries text")

events = anthropic.parse('data: {"type":"message_stop"}\n')
assert(events[1].done and events[1].content == "", "message_stop ends it without text")

events = anthropic.parse('{"type":"error","error":{"type":"not_found_error","message":"model: nope"}}\n')
assert(events[1].error == "model: nope", "a rejected request is not SSE and still has to come through")

assert(anthropic.key({ ai = {
  api_key = function()
    return "from-a-function"
  end,
} }) == "from-a-function", "a function key is called, so secrets can stay out of the config")

-- OpenAI hides the text one level deeper, in choices[1].delta.
local openai = require("ai_klammer.providers.openai")
local chat = openai.parse('data: {"choices":[{"delta":{"content":"It "},"finish_reason":null}]}\n')
assert(chat[1].content == "It " and not chat[1].done, "a delta carries text and does not end the stream")

chat = openai.parse('data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\ndata: [DONE]\n')
assert(#chat == 1 and chat[1].done and chat[1].content == "", "finish_reason ends it, [DONE] is not JSON")

chat = openai.parse('{"error":{"message":"model_not_found","type":"invalid_request_error"}}\n')
assert(chat[1].error == "model_not_found", "a rejected request still has to come through")

-- The key must never reach argv, where `ps` shows it to every process on the
-- machine. curl reads it out of a 0600 file instead.
local argv, header_lines, header_mode
local real_system = vim.system
vim.system = function(command, _, on_exit)
  argv = table.concat(command, " ")
  for index, argument in ipairs(command) do
    if argument == "--config" then
      header_lines = table.concat(vim.fn.readfile(command[index + 1]), "\n")
      header_mode = vim.uv.fs_stat(command[index + 1]).mode % 512
    end
  end
  on_exit({ code = 0, stderr = "" })
  return { kill = function() end }
end
openai.stream(
  { { role = "user", content = "hi" } },
  { ai = { api_key = "sk-secret-value", max_tokens = 16 } },
  function() end,
  function() end
)
vim.system = real_system

assert(not argv:find("sk-secret-value", 1, true), "the key is not in argv")
assert(header_lines:find("sk-secret-value", 1, true), "it is in the config file curl reads")
assert(header_mode == tonumber("600", 8), "which only its owner can read")

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

-- Disabled tools are what keep a prompt injection in someone's repo from
-- becoming a shell command. If this list is ever trimmed, that stops holding.
for _, tool in ipairs({ "Bash", "Edit", "Write", "NotebookEdit", "Read", "Glob", "Grep", "WebFetch", "Task" }) do
  assert(vim.tbl_contains(claude.no_tools, tool), tool .. " must stay disabled: repo contents are untrusted input")
end

local config = require("ai_klammer.config").setup()

-- Bring your own provider: a table with a stream function is enough.
local ai = require("ai_klammer.ai")
assert(ai.resolve(config).stream == claude.stream, "a name resolves to a bundled module")
assert(ai.resolve({ ai = { provider = "openai" } }).stream == openai.stream, "so does every other bundled name")
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

-- Where the code came from has to reach the model, or it reports the Klammer's
-- own clipping as a bug. A capturing provider is the cheapest way to look.
local sent
local spy = require("ai_klammer.config").setup({
  ai = {
    consent = true,
    provider = {
      stream = function(messages)
        sent = messages
      end,
    },
  },
})
vim.api.nvim_win_set_cursor(0, { 2, 0 })
ai.run("Why?", nil, spy)
assert(sent[2].content:find("a whole function", 1, true), "the prompt says what kind of snippet it is")
require("ai_klammer").hide()

-- A provider that cannot be cancelled returns nil. A chunk arriving after the
-- bubble was dismissed then has nothing to kill, and must not throw.
local late_chunk
local uncancellable = require("ai_klammer.config").setup({
  ai = {
    consent = true,
    provider = {
      stream = function(_, _, on_chunk)
        late_chunk = on_chunk
        return nil
      end,
    },
  },
})
-- Unscheduled, so an error surfaces here instead of in a callback nobody checks.
local real_schedule_wrap = vim.schedule_wrap
vim.schedule_wrap = function(fn)
  return fn
end
ai.run("Why?", nil, uncancellable)
vim.schedule_wrap = real_schedule_wrap
require("ai_klammer").hide()
assert(pcall(late_chunk, "too late"), "a late chunk from a provider without a handle is ignored")

-- The face follows the answer: thinking until it talks, pleased when done,
-- knocked out when it breaks.
local avatar = require("ai_klammer.ui.avatar")
local function face()
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(avatar.show()), 3, 4, false)[1]
end
local chunk, finish
local talking = require("ai_klammer.config").setup({
  ai = {
    consent = true,
    provider = {
      stream = function(_, _, on_chunk, on_done)
        chunk, finish = on_chunk, on_done
      end,
    },
  },
})
vim.schedule_wrap = function(fn)
  return fn
end
ai.run("Why?", nil, talking)
vim.schedule_wrap = real_schedule_wrap
assert(face() == "o  o ", "thinking while it waits")
chunk("It ")
assert(face() == "@  @ ", "talking once the first word is in")
finish(nil)
assert(face() == "^  ^ ", "pleased with itself when it is done")
finish("boom")
assert(face() == "x  x ", "knocked out when it fails")
require("ai_klammer").hide()

-- Nothing leaves the machine before the question has been answered once.
local asked = require("ai_klammer.config").setup({
  ai = {
    provider = {
      stream = function()
        error("sent code without asking")
      end,
    },
  },
})
require("ai_klammer.state").reset()
ai.run("Why?", nil, asked)
assert(bubble.is_open(), "it asks instead")
require("ai_klammer").hide()

-- A refusal sticks, and still does not call the provider.
require("ai_klammer.state").set_consent(false)
ai.run("Why?", nil, asked)
assert(bubble.is_open(), "it says no rather than silently doing nothing")
require("ai_klammer").hide()
require("ai_klammer.state").reset()

-- A blocklisted file is answered with silence: no request, and no bubble
-- either, because a refusal confirms the file is worth looking at.
local secret_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(secret_buf, vim.fn.tempname() .. "/.env")
vim.api.nvim_buf_set_lines(secret_buf, 0, -1, false, { "AWS_SECRET_ACCESS_KEY=nope" })
vim.api.nvim_set_current_buf(secret_buf)
sent = nil
ai.run("Why?", { 1, 1 }, spy)
assert(sent == nil, "a secrets file is never sent, even with consent given")
assert(not bubble.is_open(), "and no bubble either, which would confirm it exists")
vim.api.nvim_set_current_buf(buf)

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
