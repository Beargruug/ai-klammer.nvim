local M = {}

--- Words that appear in every question and in no useful grep.
local stopwords = {}
for word in
  ([[the a an and or but is are was were be been do does did done how what why where which who when this that these
  those there here it its of to in on at for from with without into about as by if then than so not no any all some
  can could will would should may might must i you we they me my our your their it's whats wheres hows
  der die das ein eine einen und oder aber ist sind war waren sein wie was warum wo welche wer wann hier dort
  von zu in auf bei für aus mit ohne über als wenn dann dass nicht kein keine alle etwas ich du wir sie mein unser]]):gmatch(
    "%S+"
  )
do
  stopwords[word] = true
end

--- The words from a question in prose that are worth grepping for.
--- @return table words, at most eight, in the order they were asked
function M.keywords(question)
  local seen, words = {}, {}
  for word in question:gmatch("[%w_]+") do
    local lower = word:lower()
    if #word >= 3 and not stopwords[lower] and not seen[lower] and #words < 8 then
      seen[lower] = true
      words[#words + 1] = word
    end
  end
  return words
end

--- A map of the repository by directory. The full file list would be a
--- thousand paths the model cannot use; the search hits below supply the
--- paths that matter, and this only says what kind of project it is.
--- @param files string[] tracked paths, from `git ls-files`
--- @return string|nil nil when there are none, outside a git repository
function M.layout(files)
  if not files or #files == 0 then
    return nil
  end
  local counts, dirs = {}, {}
  for _, file in ipairs(files) do
    local dir = vim.fn.fnamemodify(file, ":h")
    if not counts[dir] then
      counts[dir] = 0
      dirs[#dirs + 1] = dir
    end
    counts[dir] = counts[dir] + 1
  end
  table.sort(dirs, function(a, b)
    if counts[a] ~= counts[b] then
      return counts[a] > counts[b]
    end
    return a < b
  end)
  local parts = {}
  for index, dir in ipairs(vim.list_slice(dirs, 1, 20)) do
    parts[index] = ("%s (%d)"):format(dir, counts[dir])
  end
  return ("This project has %d tracked files: %s"):format(#files, table.concat(parts, ", "))
end

--- Group `rg --json` output by file, best file first, until the budget runs
--- out. "Best" is the file matching the most *different* keywords, not the
--- most lines: counting lines puts the changelog above the code, because
--- prose repeats one common word while the real file hits several of them.
--- @param output string
--- @return string|nil body nil when nothing readable matched
function M.body(output, config)
  local secrets = require("ai_klammer.context.secrets")
  local hits, matched, paths = {}, {}, {}

  for _, event in ipairs(require("ai_klammer.providers.shared").events(output)) do
    local data = event.type == "match" and event.data or nil
    local path = data and data.path and data.path.text
    local line = data and data.lines and data.lines.text
    -- A match inside a blocklisted file is as sensitive as the file itself.
    if path and line and not secrets.blocked(path, config) then
      if not hits[path] then
        hits[path], matched[path] = {}, {}
        paths[#paths + 1] = path
      end
      -- One minified line would otherwise eat the whole budget.
      hits[path][#hits[path] + 1] = ("%d: %s"):format(data.line_number or 0, vim.trim(line):sub(1, 200))
      for _, submatch in ipairs(data.submatches or {}) do
        matched[path][submatch.match.text:lower()] = true
      end
    end
  end

  local function score(path)
    return vim.tbl_count(matched[path])
  end
  table.sort(paths, function(a, b)
    if score(a) ~= score(b) then
      return score(a) > score(b)
    end
    if #hits[a] ~= #hits[b] then
      return #hits[a] > #hits[b]
    end
    return a < b
  end)

  -- ponytail: four characters per token, which is close enough for English
  -- and code. Swap in a real tokeniser if a provider starts rejecting this.
  local budget = config.ai.project_budget * 4
  local blocks, used = {}, 0
  for _, path in ipairs(paths) do
    local block = path .. "\n" .. table.concat(hits[path], "\n")
    if used + #block > budget then
      break
    end
    used = used + #block
    blocks[#blocks + 1] = block
  end
  if #blocks == 0 then
    return nil
  end

  local body = table.concat(blocks, "\n\n")
  return config.ai.redact and (secrets.redact(body)) or body
end

--- Search the project for whatever a question is about. ripgrep and git run
--- side by side and off the main loop, so a big repository does not freeze
--- the editor while they read it.
--- @param done fun(body: string|nil, reason: string|nil) body ready to send,
--- or a reason, "no_rg" or "no_hits". Runs on the main loop.
function M.gather(question, config, done)
  -- Before the rg check: a question with nothing to grep for is no search,
  -- with or without ripgrep, and installing it would not change the answer.
  local words = M.keywords(question)
  if #words == 0 then
    return done(nil, "no_hits")
  end
  if vim.fn.executable("rg") == 0 then
    return done(nil, "no_rg")
  end

  -- Fixed strings, because the keywords come out of prose and nobody typing a
  -- question means the brackets in it as a character class.
  local command = { "rg", "--json", "--fixed-strings", "--ignore-case", "--max-count", "3" }
  for _, word in ipairs(words) do
    command[#command + 1] = "-e"
    command[#command + 1] = word
  end

  local hits, files
  local function finish()
    if not hits or not files then
      return
    end
    local body = M.body(hits, config)
    if not body then
      return done(nil, "no_hits")
    end
    local layout = M.layout(files)
    done(layout and (layout .. "\n\n" .. body) or body)
  end

  vim.system(
    command,
    { text = true },
    vim.schedule_wrap(function(result)
      hits = result.stdout or ""
      finish()
    end)
  )
  -- vim.system throws on a missing executable, and the map is optional.
  if vim.fn.executable("git") == 0 then
    files = {}
    return
  end
  vim.system(
    { "git", "ls-files" },
    { text = true },
    vim.schedule_wrap(function(result)
      files = result.code == 0 and vim.split(result.stdout or "", "\n", { trimempty = true }) or {}
      finish()
    end)
  )
end

return M
