local M = {}

M.path = vim.fn.stdpath("data") .. "/ai_klammer.json"

local data -- { never = { [trigger] = true } }
local last = {} -- trigger -> seconds, in-memory only

local function read()
  if data then
    return data
  end
  local ok, content = pcall(vim.fn.readfile, M.path)
  local decoded = ok and select(2, pcall(vim.json.decode, table.concat(content, "\n")))
  data = type(decoded) == "table" and decoded or {}
  data.never = data.never or {}
  return data
end

function M.save()
  local dir = vim.fn.fnamemodify(M.path, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({ vim.json.encode(read()) }, M.path)
end

function M.is_never(trigger)
  return read().never[trigger] == true
end

function M.set_never(trigger)
  read().never[trigger] = true
  M.save()
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
  read().consent = answer
  M.save()
end

--- Forget every "never again", the cooldown, and the answer to the consent
--- question, so a refusal is recoverable without deleting the file by hand.
function M.reset()
  data = { never = {} }
  last = {}
  M.save()
end

--- @param cooldown number seconds; math.huge disables the trigger
function M.can_fire(trigger, cooldown)
  if M.is_never(trigger) or cooldown == math.huge then
    return false
  end
  local previous = last[trigger] or last.__any
  return previous == nil or os.time() - previous >= cooldown
end

function M.mark(trigger)
  last[trigger] = os.time()
  last.__any = last[trigger]
end

return M
