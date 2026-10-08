local M = {}

local compiled = {}

--- Vim's own glob engine does the matching, so the blocklist uses the glob
--- syntax people already know and there is no hand-rolled parser to get wrong.
local function regex(glob)
  if not compiled[glob] then
    compiled[glob] = vim.fn.glob2regpat(glob)
  end
  return compiled[glob]
end

--- True if the Klammer must never read this file.
---
--- A glob without a slash is matched against the file name alone: "*secret*"
--- compiles to an unanchored pattern, and against the whole path it would
--- block every file in a directory called secret-santa-app. Globs that do
--- contain a slash, like "*/.ssh/*", are matched against the full path, which
--- is the only way to block a directory.
--- @param path string from nvim_buf_get_name, so "" for an unsaved buffer
--- @return boolean
function M.blocked(path, config)
  if path == "" then
    return false
  end
  local name = vim.fn.fnamemodify(path, ":t")
  local full = vim.fn.fnamemodify(path, ":p")
  for _, glob in ipairs(config.ai.blocklist) do
    local subject = glob:find("/", 1, true) and full or name
    if vim.fn.match(subject, regex(glob)) >= 0 then
      return true
    end
  end
  return false
end

--- Tokens worth redacting are all long and carry a known prefix, so matching
--- the prefix is enough. Deliberately no entropy heuristic: a false positive
--- silently mangles the code the model is meant to explain, which is worse
--- than the leak it would prevent.
M.tokens = {
  "%-%-%-%-%-BEGIN[%u ]*PRIVATE KEY%-%-%-%-%-.-%-%-%-%-%-END[%u ]*PRIVATE KEY%-%-%-%-%-",
  "sk%-ant%-[%w%-_]+",
  "sk%-[%w%-_]+",
  "github_pat_[%w_]+",
  "gh[pousr]_[%w]+",
  "xox[baprs]%-[%w%-]+",
  "AKIA[%u%d]+",
  "AIza[%w%-_]+",
  "eyJ[%w%-_]+%.[%w%-_]+%.[%w%-_]+",
}

--- Names whose value is a secret when the value is long enough to be one.
local names = { "key", "secret", "token", "password", "passwd", "credential" }

local function nocase(word)
  return (word:gsub("%a", function(letter)
    return "[" .. letter:upper() .. letter:lower() .. "]"
  end))
end

local assignments = {}
for _, name in ipairs(names) do
  assignments[#assignments + 1] = "([%w_%-]*" .. nocase(name) .. "[%w_%-]*%s*[:=]%s*[\"']?)([^%s\"',;%)]+)"
end

--- Strip recognisable credentials out of code before it leaves the machine.
--- A blocklisted file never gets this far; this is for the key somebody pasted
--- into an otherwise ordinary source file.
--- @return string text
--- @return boolean whether anything was removed
function M.redact(text)
  -- Counted here rather than from gsub, which counts matches it was handed
  -- back unchanged as well as the ones actually replaced.
  local hits = 0
  for _, pattern in ipairs(M.tokens) do
    text = text:gsub(pattern, function(match)
      -- Every real token is long; the prefixes alone are not enough to be sure.
      if #match < 20 then
        return nil
      end
      hits = hits + 1
      return "[redacted]"
    end)
  end
  for _, pattern in ipairs(assignments) do
    text = text:gsub(pattern, function(prefix, value)
      if #value < 12 then
        return nil
      end
      hits = hits + 1
      return prefix .. "[redacted]"
    end)
  end
  return text, hits > 0
end

return M
