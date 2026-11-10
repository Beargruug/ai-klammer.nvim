local quips = require("ai_klammer.quips")
local state = require("ai_klammer.state")

--- The Klammer remembers you between sessions: how many there were, when it
--- last saw you, how often you said no. Counts and timestamps in the state
--- file, nothing about your code. :Klammer reset leaves it alone; delete the
--- state file to make it forget.
local M = {}

--- Back within this many seconds is a restart, not a return.
M.quick = 10 * 60
--- Away for this many seconds is worth a remark.
M.away = 3 * 24 * 3600

--- This Neovim's session, once started. setup() may run more than once.
M.session = nil

--- Count this session and note how long it has been. Once per Neovim.
--- @param now? integer os.time(), for tests
--- @return table { sessions, gap } gap in seconds, nil the very first time
function M.start(now)
  if M.session then
    return M.session
  end
  now = now or os.time()
  state.update(function(data)
    local memory = data.memory
    M.session = {
      sessions = (memory.sessions or 0) + 1,
      gap = memory.last_seen and now - memory.last_seen,
    }
    memory.sessions = M.session.sessions
    memory.last_seen = now
  end)
  return M.session
end

--- Mark the moment you left, so the next gap starts there and not at the
--- start of a session that ran all day.
function M.touch(now)
  state.update(function(data)
    data.memory.last_seen = now or os.time()
  end)
end

function M.noes()
  return state.memory().noes or 0
end

--- @return integer how many times you have said no, this one included
function M.said_no()
  local count
  state.update(function(data)
    data.memory.noes = (data.memory.noes or 0) + 1
    count = data.memory.noes
  end)
  return count
end

--- Round enough to say out loud: 10, 25, 50, then every hundred.
function M.milestone(n)
  return n == 10 or n == 25 or n == 50 or (n > 0 and n % 100 == 0)
end

--- Something about this session worth more than a plain hello.
--- @param roll? number 0..1, math.random() by default, for tests
--- @return string|nil key a quip list, the first match wins
--- @return integer|nil count for the quip's %d
function M.occasion(seen, roll)
  if seen.sessions == 1 then
    return "first_meeting"
  end
  if M.milestone(seen.sessions) then
    return "milestone", seen.sessions
  end
  if seen.gap and seen.gap >= M.away then
    return "back_after", math.floor(seen.gap / (24 * 3600))
  end
  -- Half the time: whoever restarts a lot restarts a lot.
  if seen.gap and seen.gap < M.quick and (roll or math.random()) < 0.5 then
    return "quick_restart"
  end
  return nil
end

--- What to say on arrival: the occasion if there is one, otherwise a greeting
--- that is not the one from last time, even when last time was yesterday.
function M.greeting(seen, filetype, roll)
  local key, count = M.occasion(seen, roll)
  if key then
    return quips.pick(key, count)
  end
  local last = state.memory().last_greeting
  local quip
  for _ = 1, 3 do
    quip = quips.remark("greeting", filetype)
    if quip ~= last then
      break
    end
  end
  state.update(function(data)
    data.memory.last_greeting = quip
  end)
  return quip
end

return M
