vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local search = require("ai_klammer.context.search")
local config = require("ai_klammer.config").setup()

-- A question in prose has to turn into words that exist in the code.
local words = search.keywords("How does the bubble handle a streaming answer?")
assert(vim.deep_equal(words, { "bubble", "handle", "streaming", "answer" }), table.concat(words, ","))
assert(#search.keywords("why is it so?") == 0, "a question made only of filler finds nothing to grep for")
assert(
  #search.keywords("alpha bravo charlie delta echo foxtrot golf hotel india juliett") == 8,
  "a rambling one is capped"
)

assert(vim.deep_equal(search.keywords("the Klammer and THE klammer"), { "Klammer" }), "repeats count once")

local function match(path, line, text, ...)
  local submatches = {}
  for index, word in ipairs({ ... }) do
    submatches[index] = { match = { text = word } }
  end
  return vim.json.encode({
    type = "match",
    data = { path = { text = path }, line_number = line, lines = { text = text }, submatches = submatches },
  }) .. "\n"
end

-- The file hitting the most different keywords leads, even when another file
-- has more lines: prose repeats one common word, the real file uses several.
local body = search.body(
  '{"type":"begin","data":{"path":{"text":"a.lua"}}}\n'
    .. match("a.lua", 3, "local bubble = stream()", "bubble", "stream")
    .. match("CHANGELOG.md", 7, "the bubble", "bubble")
    .. match("CHANGELOG.md", 9, "a bubble again", "bubble")
    .. match("CHANGELOG.md", 11, "still the bubble", "bubble")
    .. "not json at all\n",
  config
)
assert(body:find("^a%.lua"), "two keywords beat three lines of one:\n" .. body)
assert(body:find("3: local bubble = stream()", 1, true), "with its line numbers")
assert(body:find("CHANGELOG", 1, true) > body:find("a.lua", 1, true), "and the wordier file follows")
assert(not body:find("begin", 1, true), "events that are not matches are ignored")

-- A hit inside a blocklisted file is as sensitive as the file itself.
local blocked = search.body(match(".env", 1, "AWS_SECRET_ACCESS_KEY=nope") .. match("a.lua", 1, "ok"), config)
assert(not blocked:find("AWS_SECRET", 1, true), "a secrets file is not searchable either")
assert(blocked:find("ok", 1, true), "the rest still comes through")
assert(search.body(match("deploy/server.pem", 1, "MIIEpQIBAAKC"), config) == nil, "nothing left means nothing to send")

-- ...and a key pasted into an ordinary file goes the same way it does elsewhere.
local leaked =
  search.body(match("a.lua", 2, 'local client = OpenAI.new("sk-proj-abcdefghijklmnopqrstuvwxyz0123")'), config)
assert(not leaked:find("sk%-proj%-abcdef"), "search hits are redacted too")

-- The budget is what stops a common word from sending the whole repository.
local many = ""
for index = 1, 50 do
  many = many .. match(("file%d.lua"):format(index), index, ("x"):rep(100))
end
local tight = search.body(many, vim.tbl_deep_extend("force", config, { ai = { project_budget = 100 } }))
assert(#tight <= 400, "400 characters is 100 tokens, give or take: " .. #tight)
assert(#search.body(many, config) > #tight, "a bigger budget takes more")

-- One minified line must not eat the budget on its own.
local long = search.body(match("min.js", 1, ("y"):rep(5000)), config)
assert(#long < 300, "a long line is cut: " .. #long)

-- The layout is a map, not a file list: this repo is small but has directories.
local layout = search.layout(vim.fn.systemlist({ "git", "ls-files" }))
assert(
  layout and layout:find("lua/ai_klammer", 1, true),
  "the repository is described by directory:\n" .. tostring(layout)
)
assert(#layout < 1000, "briefly")
assert(search.layout({}) == nil, "outside a repository there is no map")

--- gather answers through a callback; wait for it.
local function gather(question)
  local called, found, reason = false, nil, nil
  search.gather(question, config, function(body, why)
    called, found, reason = true, body, why
  end)
  assert(
    vim.wait(5000, function()
      return called
    end),
    "gather never answered"
  )
  return found, reason
end

-- End to end, if the machine has rg: a real search of this repository.
if vim.fn.executable("rg") == 1 then
  local searching = true
  search.gather("where is the speech bubble drawn", config, function()
    searching = false
  end)
  assert(searching, "the search runs off the main loop, it does not answer on the spot")
  vim.wait(5000, function()
    return not searching
  end)

  local found, reason = gather("where is the speech bubble drawn")
  assert(found, "a question about this repo finds something: " .. tostring(reason))
  assert(found:find("ui/bubble.lua", 1, true), "namely the bubble:\n" .. found)
  assert(found:find("tracked files", 1, true), "with the map in front:\n" .. found)
end

assert(select(2, gather("why is it so?")) == "no_hits", "a question with no keywords is not a search")

print("ok")
