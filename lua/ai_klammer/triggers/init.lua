local bubble = require("ai_klammer.ui.bubble")
local quips = require("ai_klammer.quips")
local state = require("ai_klammer.state")

local M = {}

M.checks = {
  require("ai_klammer.triggers.regex"),
  require("ai_klammer.triggers.git"),
  require("ai_klammer.triggers.diagnostics"),
}

local group = vim.api.nvim_create_augroup("AiKlammer", { clear = true })
local debounce

function M.ignored(buf, config)
  return vim.bo[buf].buftype ~= "" or vim.tbl_contains(config.ignore_filetypes, vim.bo[buf].filetype)
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
    if vim.tbl_contains(check.events, event) and state.can_fire(check.name, config.cooldown) then
      check.check(buf, config, function(count)
        vim.schedule(function()
          if count and not bubble.is_open() and state.can_fire(check.name, config.cooldown) then
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
