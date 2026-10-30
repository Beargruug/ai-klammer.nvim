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

--- Characters per frame, and milliseconds per frame, for the typewriter.
M.chars_per_frame = 2
M.frame = 15

-- Bumped by every write that is not the typewriter's own, which stops it.
local typing = 0

--- Type the text in instead of dropping it. The window already has its final
--- size, so nothing jumps; lines fill in a few characters at a time, counted
--- in characters so an ö is never cut in half, and the last `held` lines (the
--- buttons) appear once the text is done.
--- @return integer ms how long the typing takes
local function type_out(lines, held)
  local this = typing
  local text_lines = #lines - held
  local total = 0
  for index = 1, text_lines do
    total = total + vim.fn.strchars(lines[index])
  end

  local shown = 0
  local function frame()
    local out, left = {}, shown
    for index, line in ipairs(lines) do
      if index <= text_lines then
        local length = vim.fn.strchars(line)
        out[index] = vim.fn.strcharpart(line, 0, math.max(0, math.min(length, left)))
        left = left - length
      else
        out[index] = shown >= total and line or ""
      end
    end
    write(out)
  end
  local function step()
    if this ~= typing or not M.is_open() then
      return
    end
    shown = shown + M.chars_per_frame
    frame()
    if shown < total then
      vim.defer_fn(step, M.frame)
    end
  end

  frame()
  vim.defer_fn(step, M.frame)
  return math.ceil(total / M.chars_per_frame) * M.frame
end

--- Replace the open bubble's text and regrow it. Used while an answer streams in.
function M.update(text)
  if not M.is_open() then
    return
  end
  typing = typing + 1
  local lines = wrap(text, MAX_WIDTH)
  write(lines)
  vim.api.nvim_win_set_config(win, float(lines))
  -- The window caps out at screen height, so keep the newest line in view.
  vim.api.nvim_win_set_cursor(win, { #lines, 0 })
end

function M.close()
  typing = typing + 1
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
--- @param opts? table { language, mood, buttons, focus, timeout, animate, on_yes, on_no, on_never }
--- `animate` types the text in and makes the Klammer hop; for quips, not for
--- answers, which arrive a piece at a time on their own.
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
  -- A fresh buffer per bubble, so it has to go with the window or they pile up.
  vim.bo[buf].bufhidden = "wipe"
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
  local typing_time = 0
  if opts.animate then
    avatar.hop()
    typing_time = type_out(lines, buttons and 2 or 0)
  end

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
  -- The timeout starts once the text is all there, or a long quip fades half-read.
  if opts.timeout then
    vim.defer_fn(close_this, opts.timeout + typing_time)
  end
  return win
end

return M
