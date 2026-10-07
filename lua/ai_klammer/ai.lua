local bubble = require("ai_klammer.ui.bubble")

local M = {}

M.questions = {
  explain = "Explain what this code does, then name the one thing most likely to bite.",
  regex = "Explain what this regular expression matches and where it will go wrong.",
  git = "Summarise what changed in this file and suggest how to split it into commits.",
  diagnostics = "Explain these errors and how to fix them.",
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
  },
  de = {
    thinking = "Lass mich kurz geradebiegen...",
    empty = "Da ist nichts zu erklären. Mutig, aber nichts.",
    too_big = "Das sind %d Zeilen. Ich bin eine Büroklammer, kein Aktenordner. Markier weniger.",
    no_provider = "Von einem Provider namens %s habe ich noch nie gehört.",
    unreachable = "Ich erreiche %s nicht. Läuft das? :checkhealth ai_klammer weiß mehr.",
    failed = "Das hat nicht geklappt: %s",
    silent = "Das Modell hat gar nichts gesagt. Das Gefühl kenne ich.",
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

--- Ask the configured model about the code around the cursor and stream the answer
--- into the speech bubble. <Esc> or q kills the request mid-sentence.
--- @param question string
--- @param range? table { first, last } from a command range
function M.run(question, range, config)
  config = config or require("ai_klammer").config

  local context, reason, count = require("ai_klammer.context.buffer").grab(0, range, config)
  if not context then
    return complain(config, reason, count)
  end

  local provider = M.resolve(config)
  if not provider then
    return complain(config, "no_provider", tostring(config.ai.provider))
  end

  local messages = {
    {
      role = "system",
      content = config.ai.system .. " Answer in " .. (config.language == "de" and "German." or "English."),
    },
    {
      role = "user",
      content = ("%s\n\n%s, lines %d-%d:\n```%s\n%s\n```"):format(
        question,
        context.name,
        context.first,
        context.last,
        context.filetype,
        context.text
      ),
    },
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
end

return M
