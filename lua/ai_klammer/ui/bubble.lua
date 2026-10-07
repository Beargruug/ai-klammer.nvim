local avatar = require("ai_klammer.ui.avatar")

local M = {}

local MAX_WIDTH = 46

M.buttons = {
  en = { line = "[Y]es   [N]o   Ne[v]er again", yes = "y", no = "n", never = "v" },
  de = { line = "[J]a   [N]ein   Nie [w]ieder", yes = "j", no = "n", never = "w" },
}

local ns = vim.api.nvim_create_namespace("ai_klammer_bubble")
local buf, win, prev_win

local function wrap(text, width)
  local lines = {}
  for _, paragraph in ipairs(vim.split(text, "\n", { plain = true })) do
    local line = ""
    for word in paragraph:gmatch("%S+") do
      if line == "" then
        line = word
      elseif #line + #word + 1 <= width then
        line = line .. " " .. word
      else
        lines[#lines + 1] = line
        line = word
      end
    end
    lines[#lines + 1] = line
  end
  return lines
end

--- Geometry for the given lines: bottom-right, above the Klammer, never off-screen.
local function float(lines)
  local width = 1
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local anchor = avatar.anchor()
  local height = math.max(1, math.min(#lines, anchor.row - 2))
  return {
    relative = "editor",
    row = math.max(0, anchor.row - height - 2),
    col = math.max(0, vim.o.columns - width - 3),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    zindex = 60,
  }
end

local function write(lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

function M.is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

--- Replace the open bubble's text and regrow it. Used while an answer streams in.
function M.update(text)
  if not M.is_open() then
    return
  end
  local lines = wrap(text, MAX_WIDTH)
  write(lines)
  vim.api.nvim_win_set_config(win, float(lines))
  -- The window caps out at screen height, so keep the newest line in view.
  vim.api.nvim_win_set_cursor(win, { #lines, 0 })
end

function M.close()
  local focused = M.is_open() and vim.api.nvim_get_current_win() == win
  if M.is_open() then
    vim.api.nvim_win_close(win, true)
  end
  win = nil
  if focused and prev_win and vim.api.nvim_win_is_valid(prev_win) then
    vim.api.nvim_set_current_win(prev_win)
  end
  prev_win = nil
  avatar.set_mood("neutral")
end

--- The Klammer stays put; the bubble only changes its mood.
--- @param text string
--- @param opts? table { language, mood, buttons, focus, timeout, on_yes, on_no, on_never }
function M.show(text, opts)
  opts = opts or {}
  M.close()

  local keys = M.buttons[opts.language] or M.buttons.en
  local buttons = opts.buttons
  local lines = wrap(text, MAX_WIDTH)
  if buttons then
    lines[#lines + 1] = ""
    lines[#lines + 1] = keys.line
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  write(lines)
  if buttons then
    vim.api.nvim_buf_set_extmark(buf, ns, #lines - 1, 0, { line_hl_group = "AiKlammerButton" })
  end

  local focus = opts.focus ~= false
  prev_win = focus and vim.api.nvim_get_current_win() or nil
  win = vim.api.nvim_open_win(buf, focus, float(lines))
  vim.wo[win].winhighlight = "NormalFloat:AiKlammerBubble,FloatBorder:AiKlammerBubble"
  avatar.show(opts.mood or "neutral")

  local function answer(callback)
    return function()
      M.close()
      if callback then
        callback()
      end
    end
  end

  local map = { q = answer(opts.on_no), ["<Esc>"] = answer(opts.on_no) }
  if buttons then
    map[keys.yes] = answer(opts.on_yes)
    map[keys.no] = answer(opts.on_no)
    map[keys.never] = answer(opts.on_never)
  end
  for lhs, rhs in pairs(map) do
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true })
  end

  -- Every deferred close is guarded: it must not close a bubble opened since.
  local this_win = win
  local function close_this()
    if win == this_win then
      M.close()
    end
  end

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(close_this)
    end,
  })
  if opts.timeout then
    vim.defer_fn(close_this, opts.timeout)
  end
  return win
end

return M
