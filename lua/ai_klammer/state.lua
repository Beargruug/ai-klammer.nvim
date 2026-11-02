local M = {}

M.path = vim.fn.stdpath("data") .. "/ai_klammer.json"

local data -- { never = { [trigger] = true }, consent, memory = { ... } }
local last = {} -- trigger -> seconds, in-memory only

local function load()
  local ok, content = pcall(vim.fn.readfile, M.path)
  local decoded = ok and select(2, pcall(vim.json.decode, table.concat(content, "\n")))
  local fresh = type(decoded) == "table" and decoded or {}
  fresh.never = fresh.never or {}
  fresh.memory = fresh.memory or {}
  return fresh
end

local function read()
  data = data or load()
  return data
end

function M.save()
  local dir = vim.fn.fnamemodify(M.path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode(read()) }, M.path)
end

--- Change the file, not just this Neovim's copy of it. Two Neovims open at
--- once each hold a copy; writing a stale one back would undo whatever the
--- other saved since, a consent answer included. So: re-read, change, write.
--- @param change fun(data: table)
function M.update(change)
  data = load()
  change(data)
  M.save()
end

function M.is_never(trigger)
  return read().never[trigger] == true
end

function M.set_never(trigger)
  M.update(function(fresh)
    fresh.never[trigger] = true
  end)
end

--- What the Klammer remembers about you: sessions, when it last saw you, how
--- often you said no. See ai_klammer.memory.
function M.memory()
  return read().memory
end

function M.silenced()
  return vim.tbl_keys(read().never)
end

--- Whether the user has agreed to their code leaving the machine.
--- @return boolean|nil nil when never asked, false when refused for good
function M.consent()
  return read().consent
end

function M.set_consent(answer)
  M.update(function(fresh)
    fresh.consent = answer
  end)
end

--- Forget every "never again", the cooldown, and the answer to the consent
--- question, so a refusal is recoverable without deleting the file by hand.
--- The memory stays: reset is about silencing, not about who you are.
function M.reset()
  last = {}
  M.update(function(fresh)
    fresh.never = {}
    fresh.consent = nil
  end)
end

--- Two clocks: this trigger's own, and the one every trigger shares. Both have
--- to have run out, or a trigger that fired long ago would speak up a minute
--- after another one did.
--- @param cooldown number seconds since this trigger; math.huge disables it
--- @param shared? number seconds since any trigger, `cooldown` by default
--- @param now? integer os.time(), for tests
function M.can_fire(trigger, cooldown, shared, now)
  if M.is_never(trigger) or cooldown == math.huge then
    return false
  end
  now = now or os.time()
  local function elapsed(previous, seconds)
    return previous == nil or now - previous >= seconds
  end
  return elapsed(last[trigger], cooldown) and elapsed(last.__any, shared or cooldown)
end

--- @param now? integer os.time(), for tests
function M.mark(trigger, now)
  last[trigger] = now or os.time()
  last.__any = last[trigger]
end

return M
