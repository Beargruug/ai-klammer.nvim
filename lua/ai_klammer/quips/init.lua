local M = {}

--- When this session began, for the "you have been at this a while" quips.
M.started = os.time()

--- How often a moment, when there is one, beats the plain quip.
M.moment_chance = 0.5

--- Filetypes Neovim names differently that deserve the same remark.
M.same_as = {
  bash = "sh",
  zsh = "sh",
  typescriptreact = "typescript",
  javascriptreact = "javascript",
  tf = "terraform",
}

local function set_for(language)
  local ok, set = pcall(require, "ai_klammer.quips." .. (language or "en"))
  return ok and set or require("ai_klammer.quips.en")
end

--- @param trigger string "regex" | "git" | "diagnostics"
--- @param language? string falls back to English
--- @param count? number substituted for %d in the quip
function M.pick(trigger, language, count)
  local fallback = require("ai_klammer.quips.en")
  local list = set_for(language)[trigger] or fallback[trigger]
  if not list or #list == 0 then
    return nil
  end
  return list[math.random(#list)]:format(count or 0)
end

--- What is true right now that the Klammer could have an opinion on. The
--- clock and the calendar only: nothing here comes from your code.
--- @param now? integer os.time(), for tests
--- @param started? integer when the session began, M.started by default
--- @return string[] keys into the `moments` table of a quip set
function M.moments(now, started)
  now = now or os.time()
  local date = os.date("*t", now)
  local keys = {}
  if date.hour < 5 then
    keys[#keys + 1] = "night"
  elseif date.hour < 8 then
    keys[#keys + 1] = "early"
  end
  if date.wday == 2 and date.hour < 12 then
    keys[#keys + 1] = "monday"
  elseif date.wday == 6 and date.hour >= 15 then
    keys[#keys + 1] = "friday"
  elseif date.wday == 1 or date.wday == 7 then
    keys[#keys + 1] = "weekend"
  end
  if now - (started or M.started) >= 2 * 3600 then
    keys[#keys + 1] = "long_session"
  end
  return keys
end

--- A quip about the moment when there is one and the dice agree, the plain
--- one for `trigger` otherwise. The filetype counts as a moment: it is the
--- name of a language, not a line of what you wrote in it.
--- @param filetype? string
--- @param now? integer os.time(), for tests
--- @param started? integer
function M.remark(trigger, language, filetype, now, started)
  local set, fallback = set_for(language), require("ai_klammer.quips.en")
  local lists = {}
  for _, key in ipairs(M.moments(now, started)) do
    lists[#lists + 1] = (set.moments or {})[key] or fallback.moments[key]
  end
  filetype = M.same_as[filetype] or filetype
  local by_filetype = filetype and ((set.filetypes or {})[filetype] or fallback.filetypes[filetype])
  if by_filetype then
    lists[#lists + 1] = by_filetype
  end

  if #lists == 0 or math.random() >= M.moment_chance then
    return M.pick(trigger, language)
  end
  local list = lists[math.random(#lists)]
  -- Only the long-session quips have a %d, and it is the hours so far.
  local hours = math.floor(((now or os.time()) - (started or M.started)) / 3600)
  return list[math.random(#list)]:format(hours)
end

return M
