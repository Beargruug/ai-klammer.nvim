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

-- Asking never takes the cursor: the answer streams into the corner while
-- you keep working, the way LSP hover does.
local killed, finish_slow = 0, nil
local slow = require("ai_klammer.config").setup({
  ai = {
    consent = true,
    provider = {
      stream = function(_, _, _, on_done)
        finish_slow = on_done
        return {
          kill = function()
            killed = killed + 1
          end,
        }
      end,
    },
  },
})
local editor = vim.api.nvim_get_current_win()
ai.run("Why?", nil, slow)
assert(bubble.is_open(), "the answer has a bubble")
assert(vim.api.nvim_get_current_win() == editor, "and the cursor stays where it was")

-- :Klammer focus goes in, to scroll or copy; q closes, cancels, comes back.
require("ai_klammer").focus()
assert(vim.api.nvim_get_current_win() ~= editor, "focus goes into the bubble")
vim.api.nvim_feedkeys("q", "x", false)
vim.wait(50)
assert(not bubble.is_open(), "q closes it")
assert(vim.api.nvim_get_current_win() == editor, "and puts the cursor back")
assert(killed == 1, "and cancels the request right away, not at the next chunk: " .. killed)

-- :Klammer close does the same from wherever you are, and the Klammer stays.
ai.run("Why?", nil, slow)
require("ai_klammer").close()
assert(not bubble.is_open() and killed == 2, "closed and cancelled")
assert(require("ai_klammer.ui.avatar").is_open(), "the paperclip stays")

-- A request that already finished is not killed again when its bubble goes.
ai.run("Why?", nil, slow)
finish_slow(nil)
vim.wait(50)
require("ai_klammer").close()
assert(killed == 2, "nothing left to cancel")

-- Asking again while an answer streams: the old request is cancelled, and
-- its dying words must not land in the new bubble or cancel the new request.
ai.run("First?", nil, slow)
local first_done = finish_slow
local before_second = killed
ai.run("Second?", nil, slow)
assert(killed == before_second + 1, "the first request is cancelled by the second bubble")
first_done("killed by signal 15")
vim.wait(50)
local second = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(bubble.current()), 0, -1, false))
assert(not second:find("did not work", 1, true), "the old error stays out of the new bubble: " .. second)
assert(killed == before_second + 1, "and the new request lives")
require("ai_klammer").close()

-- Complaints do not take the cursor either.
ai.run("Why?", { 4, 4 }, slow)
assert(bubble.is_open(), "a blank selection gets a remark")
assert(vim.api.nvim_get_current_win() == editor, "in the corner, not under your cursor")
require("ai_klammer").close()

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
  return vim.api.nvim_buf_get_lines(
    vim.api.nvim_win_get_buf(avatar.show()),
    avatar.eyes_row - 1,
    avatar.eyes_row,
    false
  )[1]
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

-- The git trigger's yes sends the diff, cut at max_lines rather than refused,
-- and redacted like everything else. git itself is stubbed here; the real one
-- runs in test_triggers.lua.
local git = require("ai_klammer.triggers.git")
local real_diff = git.diff
local diff_lines = { "diff --git a/a.lua b/a.lua", '+local key = "sk-' .. ("a"):rep(40) .. '"' }
for index = 1, 10 do
  table.insert(diff_lines, "+line " .. index)
end
git.diff = function(_, _, done)
  done(table.concat(diff_lines, "\n"))
end
local short = vim.tbl_deep_extend("force", spy, { ai = { max_lines = 5 } })
local named = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(named, vim.fn.tempname() .. "/a.lua")
sent = nil
ai.changes("What changed?", named, short)
local prompt = sent and sent[2].content or ""
assert(prompt:find("diff --git a/a.lua", 1, true), "the diff is sent, not the code under the cursor:\n" .. prompt)
assert(not prompt:find("sk-aaaa", 1, true), "keys in the diff are redacted")
assert(prompt:find("+line 3", 1, true) and not prompt:find("+line 4", 1, true), "cut at max_lines")
assert(prompt:find("7 more lines not sent", 1, true), "and says how much is missing")

git.diff = function(_, _, done)
  done(nil)
end
sent = nil
ai.changes("What changed?", named, spy)
assert(sent == nil, "nothing to show, nothing sent")
assert(bubble.is_open(), "but it says so")
git.diff = real_diff
require("ai_klammer").hide()
vim.api.nvim_set_current_buf(buf)

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

-- Follow-ups and :Klammer yank both work off the last whole answer.
local heard
local talker = require("ai_klammer.config").setup({
  ai = {
    consent = true,
    provider = {
      stream = function(messages, _, on_chunk, on_done)
        heard = messages
        on_chunk("Answer to " .. #messages)
        on_done(nil)
      end,
    },
  },
})
local klammer = require("ai_klammer")
local real_config = klammer.config
klammer.config = talker
local function answered(text)
  vim.wait(500, function()
    return ai.last ~= nil and ai.last.answer == text
  end)
  return ai.last and ai.last.answer
end

ai.last = nil
klammer.ask("What is this?", { 1, 3 })
assert(answered("Answer to 2") == "Answer to 2", "a first question is two messages")
assert(ai.can_follow_up(), "its answer is on screen, so the next question follows up")

klammer.ask("Why?")
assert(answered("Answer to 4") == "Answer to 4", "a follow-up is four messages")
assert(heard[3].role == "assistant" and heard[3].content == "Answer to 2", "the first answer is the model's own turn")
assert(heard[4].role == "user" and heard[4].content == "Why?", "and the new question comes last")

klammer.ask("And this?", { 1, 3 })
assert(answered("Answer to 2") == "Answer to 2", "a range is new code, so it starts over")

bubble.close()
assert(not ai.can_follow_up(), "closing the answer ends the thread")
ai.last.answer = "stale"
klammer.ask("Why?")
assert(answered("Answer to 2") == "Answer to 2", "and the next question starts fresh")

klammer.yank()
assert(vim.fn.getreg('"') == "Answer to 2", "yank copies the last answer into the unnamed register")
klammer.yank("a")
assert(vim.fn.getreg("a") == "Answer to 2", "or the one named")
klammer.config = real_config
bubble.close()

-- A finished answer fades after a reading time; at a slower pace it stays longer.
assert(ai.reading_time("one two three four", 240) == 7000, "four words at 240 a minute is a second, plus six")
assert(ai.reading_time("one two three four", 120) == 8000, "half the pace, twice the reading")
local quick = vim.tbl_deep_extend("force", talker, { ai = { answer_timeout = 50 } })
ai.last = nil
ai.send("Quick?", "code", quick)
answered("Answer to 2")
local quick_win = ai.last.win
vim.wait(300, function()
  return not vim.api.nvim_win_is_valid(quick_win)
end)
assert(not vim.api.nvim_win_is_valid(quick_win), "the answer fades once it is complete")

local stays = vim.tbl_deep_extend("force", talker, { ai = { answer_timeout = false } })
ai.last = nil
ai.send("Stay?", "code", stays)
answered("Answer to 2")
vim.wait(100)
assert(vim.api.nvim_win_is_valid(ai.last.win), "answer_timeout = false keeps it")
bubble.close()

-- The claude CLI takes one prompt, so a conversation is spelled out turn by turn.
local system, prompt = claude.prompt({
  { role = "system", content = "Be a paperclip." },
  { role = "user", content = "Hi" },
})
assert(system == "Be a paperclip." and prompt == "Hi", "one question goes as it is")
system, prompt = claude.prompt({
  { role = "system", content = "Be a paperclip." },
  { role = "user", content = "Hi" },
  { role = "assistant", content = "Hello." },
  { role = "user", content = "Why?" },
})
assert(prompt == "User: Hi\n\nAssistant: Hello.\n\nUser: Why?", "a conversation is labelled: " .. prompt)

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
