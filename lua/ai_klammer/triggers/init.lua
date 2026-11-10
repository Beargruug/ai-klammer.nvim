local bubble = require("ai_klammer.ui.bubble")
local quips = require("ai_klammer.quips")
local state = require("ai_klammer.state")

local M = {}

M.checks = {
  require("ai_klammer.triggers.regex"),
  require("ai_klammer.triggers.git"),
  require("ai_klammer.triggers.diagnostics"),
  -- Last, so a trigger with something real to say schedules its bubble first.
  require("ai_klammer.triggers.idle"),
}

local group = vim.api.nvim_create_augroup("AiKlammer", { clear = true })
-- One timer, restarted. vim.defer_fn makes a new one per call and only closes
-- it once it fires, so stopping it early leaked a handle every time.
local debounce
-- Every event since the timer last ran, not just the latest: with an
-- 'updatetime' under the debounce, the CursorHold right after :w would
-- otherwise replace the BufWritePost, and the git trigger never fires.
local pending = {}

function M.ignored(buf, config)
  return vim.bo[buf].buftype ~= ""
    or vim.tbl_contains(config.ignore_filetypes, vim.bo[buf].filetype)
    -- Not just so the answer is refused later: in a secrets file the Klammer
    -- never speaks up at all, because an unprompted bubble is one keystroke
    -- away from sending the thing.
    or require("ai_klammer.context.secrets").blocked(vim.api.nvim_buf_get_name(buf), config)
end

--- Lines either side of a regex or an error, so the model sees what it is in.
M.surrounding = 3

--- The errors in `buf`, first line first, and the lines to send for them: a
--- few either side, from the first error to the last, or from the first as
--- far as ai.max_lines allows. The ones past that are still named.
--- @return table errors
--- @return table|nil range { first, last }, nil when there are none
local function errors(buf, config)
  local found = vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
  table.sort(found, function(a, b)
    return a.lnum < b.lnum
  end)
  if #found == 0 then
    return found, nil
  end
  local first = math.max(1, found[1].lnum + 1 - M.surrounding)
  local last = math.min(vim.api.nvim_buf_line_count(buf), found[#found].lnum + 1 + M.surrounding)
  return found, { first, math.min(last, first + config.ai.max_lines - 1) }
end

--- What a yes sends: the question, and the lines to send with it. Worked out
--- when the bubble opens, while the cursor is still where the trigger fired.
--- @return string question
--- @return table|nil range { first, last }, nil for the usual function
local function request(trigger, buf, config)
  local ai = require("ai_klammer.ai")
  -- The regex, not the function around it: that could be any of the strings
  -- in it, or too long to send at all.
  if trigger == "regex" and buf == vim.api.nvim_get_current_buf() then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local first = math.max(1, row - M.surrounding)
    local last = math.min(vim.api.nvim_buf_line_count(buf), row + M.surrounding)
    return ("%s The one I mean is on line %d."):format(ai.questions.regex, row), { first, last }
  end
  if trigger ~= "diagnostics" then
    return ai.questions[trigger]
  end
  -- The code around the errors, not around the cursor: that may be a
  -- function with nothing wrong in it, or in another buffer altogether. The
  -- messages are not in the code, so they are spelled out, with their lines.
  local found, range = errors(buf, config)
  local messages = vim.tbl_map(function(diagnostic)
    return ("- line %d: %s"):format(diagnostic.lnum + 1, diagnostic.message)
  end, found)
  return ai.questions.diagnostics .. "\n" .. table.concat(messages, "\n"), range
end

--- @param buf? integer the buffer that set it off, the current one by default
function M.fire(trigger, count, config, buf)
  buf = buf or vim.api.nvim_get_current_buf()
  state.mark(trigger)

  -- A trigger with no question behind it has nothing to say yes to, so it
  -- gets the greeting's treatment: no buttons, never takes the cursor, gone
  -- again in a moment. Interrupting you for a joke would not be a joke.
  if not require("ai_klammer.ai").questions[trigger] then
    return bubble.show(quips.remark(trigger, config.language, vim.bo[buf].filetype), {
      language = config.language,
      animate = config.animate,
      focus = false,
      timeout = 4000,
    })
  end

  local question, range = request(trigger, buf, config)
  bubble.show(quips.pick(trigger, config.language, count), {
    language = config.language,
    animate = config.animate,
    mood = "thinking",
    buttons = true,
    on_yes = function()
      -- The diff it counted, not the code under the cursor.
      if trigger == "git" then
        return require("ai_klammer.ai").changes(question, buf, config)
      end
      -- Wiped while the bubble waited: there is nothing left to ask about.
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      -- From the buffer that fired, which need not be the current one: a
      -- range never reads the cursor, and every trigger with a range sends one.
      require("ai_klammer.ai").run(question, range, config, range and buf or nil)
    end,
    -- Every no is counted. The round ones get said out loud, briefly.
    on_no = function()
      local count = require("ai_klammer.memory").said_no()
      if require("ai_klammer.memory").milestone(count) then
        bubble.show(quips.pick("noes", config.language, count), {
          language = config.language,
          animate = config.animate,
          mood = "annoyed",
          focus = false,
          timeout = 4000,
        })
      end
    end,
    on_never = function()
      state.set_never(trigger)
    end,
  })
end

--- @param events table<string, true> every event since the last run
local function run(events, buf, config)
  if not vim.api.nvim_buf_is_valid(buf) or bubble.is_open() or M.ignored(buf, config) then
    return
  end
  local function wants(check)
    for _, event in ipairs(check.events) do
      if events[event] then
        return true
      end
    end
    return false
  end
  for _, check in ipairs(M.checks) do
    -- A check may ask to be rarer than the shared cooldown, never louder.
    local cooldown = math.max(check.cooldown or 0, config.cooldown)
    if wants(check) and state.can_fire(check.name, cooldown, config.cooldown) then
      check.check(buf, config, function(count)
        vim.schedule(function()
          if count and not bubble.is_open() and state.can_fire(check.name, cooldown, config.cooldown) then
            M.fire(check.name, count, config, buf)
          end
        end)
      end)
    end
  end
end

function M.setup(config)
  vim.api.nvim_clear_autocmds({ group = group })
  if config.annoyance == 0 then
    return
  end
  vim.api.nvim_create_autocmd({ "CursorHold", "BufWritePost" }, {
    group = group,
    callback = function(args)
      pending[args.event] = true
      debounce = debounce or vim.uv.new_timer()
      debounce:stop()
      debounce:start(
        300,
        0,
        vim.schedule_wrap(function()
          local events = pending
          pending = {}
          run(events, args.buf, config)
        end)
      )
    end,
  })
end

return M
