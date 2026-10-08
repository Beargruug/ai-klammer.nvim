local bubble = require("ai_klammer.ui.bubble")

local M = {}

M.questions = {
  explain = "Explain what this code does, then name the one thing most likely to bite.",
  regex = "Explain what this regular expression matches and where it will go wrong.",
  git = "Summarise what changed in this file and suggest how to split it into commits.",
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
    consent = "Bevor ich das beantworte: Der Code, den ich ansehe, geht an %s. "
      .. "Einmal ja, dann frage ich nicht mehr.",
    refused = "Du hast gesagt, mein Code soll nirgendwohin. Also bleibt er hier. :Klammer reset, falls du es dir anders überlegst.",
  },
}

local function say(language, key, ...)
  local set = phrases[language] or phrases.en
  return (set[key] or phrases.en[key]):format(...)
end

local function complain(config, key, ...)
  bubble.show(say(config.language, key, ...), { language = config.language, mood = "annoyed" })
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
--- the user only pressed y on, and whatever Phase 4 adds.
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

--- Put a question and an already-assembled block of context to the model.
--- @param question string
--- @param body string the context, formatted and already safe to send
function M.send(question, body, config)
  config = config or require("ai_klammer").config

  local provider = M.resolve(config)
  if not provider then
    return complain(config, "no_provider", tostring(config.ai.provider))
  end

  local messages = {
    {
      role = "system",
      content = config.ai.system .. " Answer in " .. (config.language == "de" and "German." or "English."),
    },
    { role = "user", content = question .. "\n\n" .. body },
  }

  local handle
  local answer = ""

  local on_chunk = vim.schedule_wrap(function(text)
    -- The bubble is gone: the user walked away, so stop paying for tokens.
    if not bubble.is_open() then
      return handle:kill(15)
    end
    answer = answer .. text
    bubble.update(answer)
  end)

  local on_done = vim.schedule_wrap(function(err)
    if not bubble.is_open() then
      return
    end
    if err and err:lower():find("connect") then
      complain(config, "unreachable", config.ai.url or provider.url or "the model server")
    elseif err then
      complain(config, "failed", err)
    elseif vim.trim(answer) == "" then
      complain(config, "silent")
    end
  end)

  consented(config, function()
    bubble.show(say(config.language, "thinking"), {
      language = config.language,
      mood = "thinking",
      on_no = function()
        if handle then
          handle:kill(15)
        end
      end,
    })
    handle = provider.stream(messages, config, on_chunk, on_done)
  end)
end

return M
