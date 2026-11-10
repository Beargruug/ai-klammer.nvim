local bubble = require("ai_klammer.ui.bubble")

local M = {}

M.questions = {
  explain = "Explain what this code does, then name the one thing most likely to bite.",
  regex = "Explain what this regular expression matches and where it will go wrong.",
  git = "Summarise what changed and suggest how to split it into commits.",
  diagnostics = "Explain these errors and how to fix them.",
}

--- Where the code came from, so the model does not report a half-caught
--- expression as a bug when the Klammer was the one holding the scissors.
local sources = {
  selection = "a selection",
  ["function"] = "a whole function",
  nearby = "an arbitrary slice around the cursor, so it may start or end mid-expression",
}

local phrases = {
  en = {
    thinking = "Let me unbend for a second...",
    empty = "There is nothing there to explain. Bold, but nothing.",
    too_big = "That is %d lines. I am a paperclip, not a ring binder. Select less.",
    no_provider = "I have never heard of a provider called %s.",
    unreachable = "I cannot reach %s. Is it running? :checkhealth ai_klammer knows more.",
    failed = "That did not work: %s",
    silent = "The model said nothing at all. I know the feeling.",
    no_rg = "I look things up with ripgrep, and ripgrep is not on your PATH. Install it and ask me again.",
    no_hits = "I searched the whole project and found nothing to do with that. Try words that appear in the code.",
    no_changes = "I asked git, and it has no changes I could show you. Committed in the meantime?",
    consent = "Before I answer that: the code I am looking at gets sent to %s. "
      .. "Say yes once and I will stop asking.",
    refused = "You told me never to send your code anywhere, so I will not. :Klammer reset if you change your mind.",
  },
  de = {
    thinking = "Lass mich kurz geradebiegen...",
    empty = "Da ist nichts zu erklären. Mutig, aber nichts.",
    too_big = "Das sind %d Zeilen. Ich bin eine Büroklammer, kein Aktenordner. Markier weniger.",
    no_provider = "Von einem Provider namens %s habe ich noch nie gehört.",
    unreachable = "Ich erreiche %s nicht. Läuft das? :checkhealth ai_klammer weiß mehr.",
    failed = "Das hat nicht geklappt: %s",
    silent = "Das Modell hat gar nichts gesagt. Das Gefühl kenne ich.",
    no_rg = "Ich schlage mit ripgrep nach, und ripgrep liegt nicht in deinem PATH. Installier es und frag noch mal.",
    no_hits = "Ich habe das ganze Projekt durchsucht und nichts dazu gefunden. Nimm Wörter, die im Code vorkommen.",
    no_changes = "Ich habe git gefragt, und da sind keine Änderungen, die ich zeigen könnte. Zwischendurch committet?",
    consent = "Bevor ich das beantworte: Der Code, den ich ansehe, geht an %s. "
      .. "Einmal ja, dann frage ich nicht mehr.",
    refused = "Du hast gesagt, mein Code soll nirgendwohin. Also bleibt er hier. :Klammer reset, falls du es dir anders überlegst.",
  },
}

local function say(language, key, ...)
  local set = phrases[language] or phrases.en
  return (set[key] or phrases.en[key]):format(...)
end

--- A broken request knocks the Klammer out; everything else merely annoys it.
local moods = { failed = "dead", unreachable = "dead", silent = "dead" }

--- In the corner, not under your cursor: a remark is read, not answered.
local function complain(config, key, ...)
  bubble.show(say(config.language, key, ...), {
    language = config.language,
    mood = moods[key] or "annoyed",
    focus = false,
  })
end

--- A provider is anything with a stream function. `ai.provider` is either one
--- of those outright, or the name of a module under ai_klammer.providers.
--- @return table|nil
function M.resolve(config)
  if type(config.ai.provider) == "table" then
    return config.ai.provider
  end
  local ok, module = pcall(require, "ai_klammer.providers." .. config.ai.provider)
  return ok and type(module) == "table" and type(module.stream) == "function" and module or nil
end

--- Ask once, ever, before any code leaves the machine, and remember the answer.
--- Every path that sends code goes through here: a typed command, a trigger
--- the user only pressed y on, and a :Klammer project search.
local function consented(config, continue)
  local state = require("ai_klammer.state")
  local answer = config.ai.consent
  if answer == nil then
    answer = state.consent()
  end
  if answer == true then
    return continue()
  end
  if answer == false then
    return complain(config, "refused")
  end

  local provider = type(config.ai.provider) == "string" and config.ai.provider or "the provider you configured"
  bubble.show(say(config.language, "consent", provider), {
    language = config.language,
    mood = "thinking",
    buttons = true,
    on_yes = function()
      state.set_consent(true)
      continue()
    end,
    on_never = function()
      state.set_consent(false)
    end,
  })
end

--- Ask the configured model about the code around the cursor and stream the answer
--- into the speech bubble. <Esc> or q kills the request mid-sentence.
--- @param question string
--- @param range? table { first, last } from a command range
function M.run(question, range, config)
  config = config or require("ai_klammer").config

  local context, reason, count = require("ai_klammer.context.buffer").grab(0, range, config)
  if not context then
    -- A blocklisted file is answered with silence. Saying "I will not read
    -- that" would confirm the file exists and is worth looking at.
    if reason ~= "blocked" then
      complain(config, reason, count)
    end
    return
  end

  M.send(
    question,
    ("%s, lines %d-%d, %s:\n```%s\n%s\n```"):format(
      context.name,
      context.first,
      context.last,
      sources[context.source] or "some code",
      context.filetype,
      context.text
    ),
    config
  )
end

--- Ask about the project rather than the buffer: ripgrep finds the files the
--- question is about, the model gets the matching lines. Consent, redaction
--- and the kill switch come from send(), this only assembles a body.
--- @param question string
function M.project(question, config)
  config = config or require("ai_klammer").config

  require("ai_klammer.context.search").gather(question, config, function(body, reason)
    if not body then
      return complain(config, reason)
    end
    M.send(question, "Matches from this project:\n\n" .. body, config)
  end)
end

--- Ask about the uncommitted changes rather than the code under the cursor,
--- which may well be the one function you did not touch. The diff is cut at
--- ai.max_lines instead of refused: the trigger only fires on big diffs, so
--- refusing would refuse nearly every time.
--- @param question string
--- @param buf integer a buffer inside the repository
function M.changes(question, buf, config)
  config = config or require("ai_klammer").config
  local secrets = require("ai_klammer.context.secrets")
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return complain(config, "no_changes")
  end

  local function blocked(file)
    return secrets.blocked(file, config)
  end
  require("ai_klammer.triggers.git").diff(vim.fs.dirname(path), blocked, function(diff)
    if not diff or vim.trim(diff) == "" then
      return complain(config, "no_changes")
    end
    local lines = vim.split(vim.trim(diff), "\n", { plain = true })
    if #lines > config.ai.max_lines then
      local cut = #lines - config.ai.max_lines
      lines = vim.list_slice(lines, 1, config.ai.max_lines)
      table.insert(lines, ("... cut off here, %d more lines not sent"):format(cut))
    end
    local text = table.concat(lines, "\n")
    if config.ai.redact then
      text = secrets.redact(text)
    end
    M.send(question, "Uncommitted changes against HEAD:\n```diff\n" .. text .. "\n```", config)
  end)
end

--- Long enough to read an answer: a few seconds to notice it is done, then
--- the words at `words_per_minute`. The default, 240, is slow reading on
--- purpose: code in prose is read slower than prose.
--- @return integer ms
function M.reading_time(text, words_per_minute)
  local words = select(2, text:gsub("%S+", ""))
  return 6000 + math.ceil(words * 60000 / words_per_minute)
end

--- The last answer that arrived whole, with the conversation that led to it
--- and the bubble it is in: { messages, answer, win }. What :Klammer yank
--- copies, and what a follow-up question continues.
M.last = nil

--- Stream a conversation into a fresh bubble in the corner.
local function converse(messages, config)
  local provider = M.resolve(config)
  if not provider then
    return complain(config, "no_provider", tostring(config.ai.provider))
  end

  local handle, mine
  local finished, cancelled = false, false
  local answer = ""

  -- Once, and only while it runs. A provider that cannot be cancelled
  -- returned no handle; its text is simply dropped.
  local function cancel()
    if handle and not finished and not cancelled then
      cancelled = true
      handle:kill(15)
    end
  end
  -- This request's bubble, not just any: a second question replaces it, and
  -- the first one's last words must not land in the second one's bubble.
  local function ours()
    return mine ~= nil and bubble.current() == mine
  end

  local on_chunk = vim.schedule_wrap(function(text)
    -- The bubble is gone: the user walked away, so stop paying for tokens.
    if not ours() then
      return cancel()
    end
    -- Done thinking once it starts talking.
    if answer == "" then
      require("ai_klammer.ui.avatar").set_mood("neutral")
    end
    answer = answer .. text
    bubble.update(answer)
  end)

  local on_done = vim.schedule_wrap(function(err)
    finished = true
    if not ours() then
      return
    end
    if err and err:lower():find("connect") then
      complain(config, "unreachable", config.ai.url or provider.url or "the model server")
    elseif err then
      complain(config, "failed", err)
    elseif vim.trim(answer) == "" then
      complain(config, "silent")
    else
      M.last = { messages = messages, answer = answer, win = mine }
      -- Once it is complete, not while it streams: a slow model is not a
      -- reason to take the answer away.
      local timeout = config.ai.answer_timeout
      if timeout then
        bubble.fade(mine, timeout == "auto" and M.reading_time(answer, config.ai.words_per_minute) or timeout)
      end
      -- Faintly pleased with itself, as per the system prompt.
      require("ai_klammer.ui.avatar").react("happy")
    end
  end)

  consented(config, function()
    -- The answer streams into the corner while you keep working; :Klammer
    -- focus to scroll it, and closing it in any way cancels the request.
    mine = bubble.show(say(config.language, "thinking"), {
      language = config.language,
      mood = "thinking",
      focus = false,
      on_close = cancel,
    })
    handle = provider.stream(messages, config, on_chunk, on_done)
  end)
end

--- Put a question and an already-assembled block of context to the model.
--- @param question string
--- @param body string the context, formatted and already safe to send
function M.send(question, body, config)
  config = config or require("ai_klammer").config
  converse({
    {
      role = "system",
      content = config.ai.system .. " Answer in " .. (config.language == "de" and "German." or "English."),
    },
    { role = "user", content = question .. "\n\n" .. body },
  }, config)
end

--- A question continues the last conversation while its answer is still on
--- screen. Once the bubble is gone, so is the thread: closing it is how you
--- start over, and nothing is carried along that you can no longer see.
--- @return boolean
function M.can_follow_up()
  return M.last ~= nil and bubble.current() == M.last.win
end

--- Ask about the answer on screen: the whole conversation goes again, with
--- the answer as the model's own turn, so "why?" means why that.
--- @param question string
function M.follow_up(question, config)
  config = config or require("ai_klammer").config
  local messages = vim.deepcopy(M.last.messages)
  vim.list_extend(messages, {
    { role = "assistant", content = M.last.answer },
    { role = "user", content = question },
  })
  converse(messages, config)
end

return M
