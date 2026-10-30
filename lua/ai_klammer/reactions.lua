local avatar = require("ai_klammer.ui.avatar")

--- Faces, not words. The triggers speak up and offer something; these only
--- change the Klammer's expression for a moment, so they need no cooldown,
--- never open a bubble, and never read a line of your code.
local M = {}

--- Lines added or removed in one change before the Klammer looks startled.
M.big_change = 20

local group = vim.api.nvim_create_augroup("AiKlammerReactions", { clear = true })
local lines, errors = {}, {} -- buffer -> what it was a moment ago

local function error_count(buf)
  return #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
end

function M.setup(config)
  vim.api.nvim_clear_autocmds({ group = group })
  lines, errors = {}, {}
  if config.annoyance == 0 then
    return
  end

  local ignored = require("ai_klammer.triggers").ignored
  local function watch(events, callback)
    vim.api.nvim_create_autocmd(events, {
      group = group,
      callback = function(args)
        if avatar.is_open() and vim.api.nvim_buf_is_valid(args.buf) and not ignored(args.buf, config) then
          callback(args.buf, args.event)
        end
      end,
    })
  end

  -- A clean save earns a smile. Faint praise, but praise.
  watch("BufWritePost", function(buf)
    if error_count(buf) == 0 then
      avatar.react("happy")
    end
  end)

  -- More errors than a moment ago. Not in insert mode, where half a word is
  -- always an error and the face would never stop twitching.
  watch("DiagnosticChanged", function(buf)
    local count = error_count(buf)
    if count > (errors[buf] or 0) and not vim.api.nvim_get_mode().mode:find("^i") then
      avatar.react("annoyed")
    end
    errors[buf] = count
  end)

  -- A paste or an undo that moves a lot of lines at once.
  watch({ "BufEnter", "TextChanged", "TextChangedI" }, function(buf, event)
    local count = vim.api.nvim_buf_line_count(buf)
    if event ~= "BufEnter" and lines[buf] and math.abs(count - lines[buf]) >= M.big_change then
      avatar.react("surprised")
    end
    lines[buf] = count
  end)
end

return M
