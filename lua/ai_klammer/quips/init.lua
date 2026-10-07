local M = {}

--- @param trigger string "regex" | "git" | "diagnostics"
--- @param language? string falls back to English
--- @param count? number substituted for %d in the quip
function M.pick(trigger, language, count)
  local fallback = require("ai_klammer.quips.en")
  local ok, set = pcall(require, "ai_klammer.quips." .. (language or "en"))
  local list = (ok and set[trigger]) or fallback[trigger]
  if not list or #list == 0 then
    return nil
  end
  return list[math.random(#list)]:format(count or 0)
end

return M
