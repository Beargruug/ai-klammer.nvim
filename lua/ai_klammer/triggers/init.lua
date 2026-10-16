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
local debounce

function M.ignored(buf, config)
  return vim.bo[buf].buftype ~= ""
    or vim.tbl_contains(config.ignore_filetypes, vim.bo[buf].filetype)
    -- Not just so the answer is refused later: in a secrets file the Klammer
    -- never speaks up at all, because an unprompted bubble is one keystroke
    -- away from sending the thing.
    or require("ai_klammer.context.secrets").blocked(vim.api.nvim_buf_get_name(buf), config)
end

--- The diagnostics the Klammer counted are not in the code it sends, so spell them out.
local function question(trigger)
  local ai = require("ai_klammer.ai")
  if trigger ~= "diagnostics" then
    return ai.questions[trigger]
  end
  local messages = vim.tbl_map(function(diagnostic)
    return "- " .. diagnostic.message
  end, vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }))
  return ai.questions.diagnostics .. "\n" .. table.concat(messages, "\n")
end

function M.fire(trigger, count, config)
  state.mark(trigger)

  -- A trigger with no question behind it has nothing to say yes to, so it
  -- gets the greeting's treatment: no buttons, never takes the cursor, gone
  -- again in a moment. Interrupting you for a joke would not be a joke.
  if not require("ai_klammer.ai").questions[trigger] then
    return bubble.show(quips.pick(trigger, config.language, count), {
      language = config.language,
      focus = false,
      timeout = 4000,
    })
  end

  bubble.show(quips.pick(trigger, config.language, count), {
    language = config.language,
    mood = "thinking",
    buttons = true,
    on_yes = function()
      require("ai_klammer.ai").run(question(trigger), nil, config)
    end,
    on_never = function()
      state.set_never(trigger)
    end,
  })
end

local function run(event, buf, config)
  if not vim.api.nvim_buf_is_valid(buf) or bubble.is_open() or M.ignored(buf, config) then
    return
  end
  for _, check in ipairs(M.checks) do
    -- A check may ask to be rarer than the shared cooldown, never louder.
    local cooldown = math.max(check.cooldown or 0, config.cooldown)
    if vim.tbl_contains(check.events, event) and state.can_fire(check.name, cooldown) then
      check.check(buf, config, function(count)
        vim.schedule(function()
          if count and not bubble.is_open() and state.can_fire(check.name, cooldown) then
            M.fire(check.name, count, config)
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
      if debounce then
        debounce:stop()
      end
      debounce = vim.defer_fn(function()
        run(args.event, args.buf, config)
      end, 300)
    end,
  })
end

return M
