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
assert(argv:find("--connect-timeout", 1, true), "an unreachable host fails fast")
assert(header_lines:find("sk-secret-value", 1, true), "it is in the config file curl reads")
assert(header_mode == tonumber("600", 8), "which only its owner can read")

-- Hitting max_tokens is flagged by every bundled parser, so it can be said out loud.
assert(
  anthropic.parse('data: {"type":"message_delta","delta":{"stop_reason":"max_tokens"}}\n')[1].cut,
  "anthropic: stop_reason max_tokens is a cut"
)
assert(
  not anthropic.parse('data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}\n')[1].cut,
  "anthropic: end_turn is not"
)
assert(
  openai.parse('data: {"choices":[{"delta":{},"finish_reason":"length"}]}\n')[1].cut,
  "openai: finish_reason length is a cut"
)
assert(not openai.parse('data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n')[1].cut, "openai: stop is not")

-- shared.run passes the cut on to on_done.
local cut_info
local real_system_cut = vim.system
vim.system = function(_, opts, on_exit)
  opts.stdout(nil, 'data: {"type":"message_delta","delta":{"stop_reason":"max_tokens"}}\n')
  on_exit({ code = 0, stderr = "" })
  return { kill = function() end }
end
shared.run({ "x" }, "", anthropic.parse, function() end, function(_, info)
  cut_info = info
end)
vim.system = real_system_cut
assert(cut_info and cut_info.cut, "on_done hears that the answer was cut")

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

-- Something else pushing the answer aside, a fade or a quip, is not you
-- saying you are done.
bubble.close()
assert(ai.can_follow_up(), "an answer that went away on its own keeps the thread")

-- Another buffer is other code: "why?" over there is not about this answer.
local elsewhere = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(elsewhere)
assert(not ai.can_follow_up(), "asking from another buffer starts over")
vim.api.nvim_set_current_buf(buf)
assert(ai.can_follow_up(), "and coming back picks it up again")

klammer.close()
assert(not ai.can_follow_up(), ":Klammer close ends the thread")
ai.last.answer = "stale"
klammer.ask("Why?")
assert(answered("Answer to 2") == "Answer to 2", "and the next question starts fresh")

-- q in the answer ends it as well.
bubble.focus()
vim.api.nvim_feedkeys("q", "x", false)
vim.wait(50)
assert(not ai.can_follow_up(), "q in the answer ends the thread")

-- :Klammer last shows the answer again and picks the thread back up.
bubble.close()
klammer.last()
assert(bubble.is_open() and ai.last.win == bubble.current(), "the last answer is back on screen")
local again = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(bubble.current()), 0, -1, false))
assert(again == "Answer to 2", "with its text: " .. again)
assert(ai.can_follow_up(), "and you can ask about it again")

-- :Klammer history offers the last answers, newest first, by their question.
assert(#ai.history >= 2 and ai.history[1] == ai.last, "newest first")
assert(ai.label(ai.history[1]) == "Why?", "listed by the question: " .. ai.label(ai.history[1]))
local real_select = vim.ui.select
vim.ui.select = function(items, opts, choose)
  assert(opts.format_item(items[2]) ~= nil, "every entry has a label")
  choose(items[2])
end
local older = ai.history[2]
klammer.history()
vim.ui.select = real_select
assert(ai.last == older and bubble.current() == older.win, "picking one shows it and makes it the thread")
for _ = 1, ai.history_size + 2 do
  table.insert(ai.history, 1, older)
end
ai.send("One more?", "code", talker)
vim.wait(500, function()
  return ai.last ~= older
end)
assert(ai.history[1] ~= older, "the new answer is in")
assert(#ai.history == ai.history_size, "only the last few are kept")

-- A conversation past ai.max_context starts over instead of growing further.
assert(ai.tokens("abcd") >= 1 + math.ceil(#ai.last.answer / 4), "the question and the answer both count")
assert(ai.fits("Why?", talker), "a short conversation fits")
local tight = vim.tbl_deep_extend("force", talker, { ai = { max_context = 1 } })
assert(not ai.fits("Why?", tight), "and does not under a tiny limit")
klammer.config = tight
klammer.ask("Why?")
vim.wait(500, function()
  return heard and #heard == 2 and heard[2].content:find("^Why%?") ~= nil
end)
assert(#heard == 2, "past the limit, the follow-up is sent as a new question: " .. #heard)
klammer.config = talker
assert(not pcall(require("ai_klammer.config").setup, { ai = { max_context = 0 } }), "a limit of zero is refused")

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

-- ai.brief asks for the point first and little else; off by default.
ai.send("Why?", "code", talker)
assert(not heard[1].content:find("first sentence", 1, true), "answers are not squeezed by default")
local terse = vim.tbl_deep_extend("force", talker, { ai = { brief = true } })
ai.send("Why?", "code", terse)
assert(heard[1].content:find("first sentence", 1, true), "brief puts the answer first")
assert(heard[1].content:find(terse.ai.system, 1, true), "and keeps the Klammer's voice")
bubble.close()

-- An answer cut off at max_tokens says so under the answer, and only there.
local clipped = vim.tbl_deep_extend("force", talker, {
  ai = {
    answer_timeout = false,
    max_tokens = 7,
    provider = {
      stream = function(_, _, on_chunk, on_done)
        on_chunk("Half an ans")
        on_done(nil, { cut = true })
      end,
    },
  },
})
ai.last = nil
ai.send("Long?", "code", clipped)
vim.wait(500, function()
  return ai.last ~= nil
end)
local shown_cut =
  table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(bubble.current()), 0, -1, false), " ")
assert(shown_cut:find("ai.max_tokens = 7", 1, true), "the bubble says where it stopped: " .. shown_cut)
assert(ai.last.answer == "Half an ans", "but the answer itself stays clean for yank and follow-ups")
bubble.close()

-- A request that goes quiet is hung up on, and says so.
local hung_up = false
local mute = vim.tbl_deep_extend("force", talker, {
  ai = {
    request_timeout = 50,
    provider = {
      stream = function()
        return {
          kill = function()
            hung_up = true
          end,
        }
      end,
    },
  },
})
ai.send("Hello?", "code", mute)
vim.wait(300, function()
  return hung_up
end)
assert(hung_up, "a silent request is killed after request_timeout")
local said = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(bubble.current()), 0, -1, false), " ")
assert(said:find("hung up", 1, true), "and the Klammer says why: " .. said)
bubble.close()

-- Quiet, not slow: a chunk every 30 ms keeps a 50 ms timeout from firing.
local cut = false
local steady = vim.tbl_deep_extend("force", talker, {
  ai = {
    request_timeout = 50,
    answer_timeout = false,
    provider = {
      stream = function(_, _, on_chunk, on_done)
        local count = 0
        local function tick()
          count = count + 1
          if count > 6 then
            return on_done(nil)
          end
          on_chunk("word ")
          vim.defer_fn(tick, 30)
        end
        tick()
        return {
          kill = function()
            cut = true
          end,
        }
      end,
    },
  },
})
ai.last = nil
ai.send("Slowly?", "code", steady)
vim.wait(500, function()
  return ai.last ~= nil
end)
assert(not cut and ai.last and vim.trim(ai.last.answer) == vim.trim(("word "):rep(6)), "a steady answer is never cut")
bubble.close()

-- So does a complaint: "nothing to explain" is read once, not kept.
vim.api.nvim_set_current_buf(buf)
ai.run("Why?", { 4, 4 }, quick)
local complaint = bubble.current()
assert(complaint, "a blank selection gets a remark")
vim.wait(300, function()
  return not vim.api.nvim_win_is_valid(complaint)
end)
assert(not vim.api.nvim_win_is_valid(complaint), "and the remark fades too")

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
local win = bubble.show("Let me unbend for a second...", { focus = false })
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
