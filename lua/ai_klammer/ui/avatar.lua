local M = {}

M.eyes = {
  neutral = "@  @ ",
  blink = "-  - ",
  thinking = "o  o ",
  annoyed = ">  < ",
  happy = "^  ^ ",
  surprised = "O  O ",
  dead = "x  x ",
  left = "◐  ◐ ",
  right = "◑  ◑ ",
}

local body = {
  " __  ",
  "/  \\ ",
  "|  | ",
  false, -- eyes
  "|  | ",
  "|| |/",
  "|| ||",
  "|\\_/|",
  "\\___/",
}

M.width = 5
M.height = #body

--- How long without a keypress before the Klammer nods off, in milliseconds.
M.sleep_after = 5 * 60 * 1000

local buf, win, timer
local mood = "neutral"
local reaction, reaction_token -- a passing expression over the mood
local gaze -- "left" | "right" | nil when looking straight out
local blinking = false
local asleep = false
local snore = 0 -- 0 quiet, 1 a z beside the head, 2 a Z above it
local last_active = vim.uv.now()

--- Blink beats sleep beats reaction beats mood beats gaze.
local function eyes()
  if blinking or asleep then
    return M.eyes.blink
  end
  if reaction then
    return M.eyes[reaction]
  end
  if mood ~= "neutral" then
    return M.eyes[mood]
  end
  -- The half circles are ambiguous width: with ambiwidth=double they take
  -- two cells each and tear the wire apart, so it looks straight ahead.
  if gaze and vim.o.ambiwidth == "single" then
    return M.eyes[gaze]
  end
  return M.eyes.neutral
end

local function render()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines = {}
  for i, line in ipairs(body) do
    lines[i] = line or eyes()
  end
  -- The free column right of the head, where the z drifts up.
  if asleep and snore == 1 then
    lines[2] = lines[2]:sub(1, 4) .. "z"
  elseif asleep and snore == 2 then
    lines[1] = lines[1]:sub(1, 4) .. "Z"
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--- Bottom-right corner, above the statusline and the command area.
function M.anchor()
  local bottom = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  return {
    row = math.max(0, bottom - M.height),
    col = math.max(0, vim.o.columns - M.width - 1),
  }
end

local function reposition()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, vim.tbl_extend("force", M.anchor(), { relative = "editor" }))
  end
end

function M.is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

--- Somewhere between two and eight seconds, like a face and unlike a metronome.
function M.next_blink()
  return math.random(2000, 8000)
end

local function blink(times)
  blinking = true
  render()
  vim.defer_fn(function()
    blinking = false
    render()
    if times > 1 then
      vim.defer_fn(function()
        if M.is_open() and not asleep then
          blink(times - 1)
        end
      end, 120)
    end
  end, 150)
end

--- One timer for the whole face: a blink at a random moment while awake,
--- the next frame of the snoring every second while asleep.
local function tick()
  if not (M.is_open() and timer) then
    return
  end
  if not asleep and vim.uv.now() - last_active >= M.sleep_after then
    M.sleep()
  end
  if asleep then
    snore = snore % 2 + 1
    render()
    return timer:start(1000, 0, vim.schedule_wrap(tick))
  end
  -- Now and then a double blink, which is most of what makes it look alive.
  blink(math.random() < 0.2 and 2 or 1)
  timer:start(M.next_blink(), 0, vim.schedule_wrap(tick))
end

local function start_ticking()
  if timer then
    return
  end
  timer = vim.uv.new_timer()
  timer:start(M.next_blink(), 0, vim.schedule_wrap(tick))
end

--- A passing expression over whatever the mood is, gone again after `ms`.
--- @param name string a key of M.eyes
--- @param ms? number how long it holds, 1500 by default
function M.react(name, ms)
  if not M.eyes[name] then
    return
  end
  reaction = name
  local token = {}
  reaction_token = token
  render()
  vim.defer_fn(function()
    if reaction_token == token then
      reaction = nil
      render()
    end
  end, ms or 1500)
end

--- Thirds of the editor: the eyes go where the cursor is.
--- @return string|nil "left", "right", or nil for straight ahead
function M.gaze_for(col, columns)
  if col <= columns / 3 then
    return "left"
  elseif col > columns * 2 / 3 then
    return "right"
  end
  return nil
end

function M.look(direction)
  if direction ~= gaze then
    gaze = direction
    render()
  end
end

function M.sleep()
  asleep = true
  snore = 0
  render()
  -- Snoring runs on a one-second beat, not on the next blink up to eight away.
  if timer then
    timer:start(1000, 0, vim.schedule_wrap(tick))
  end
end

function M.asleep()
  return asleep
end

--- You are there. If the Klammer had nodded off, it wakes with a start.
function M.poke()
  last_active = vim.uv.now()
  if asleep then
    asleep = false
    snore = 0
    M.react("surprised", 800)
  end
end

--- A mood set on purpose wipes out a passing reaction: a failed request must
--- not stay hidden behind the smile from the answer before it.
local function set_mood(new_mood)
  if M.eyes[new_mood] then
    mood = new_mood
    reaction, reaction_token = nil, nil
  end
end

function M.show(new_mood)
  set_mood(new_mood)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "ai_klammer"
  end
  if not M.is_open() then
    local anchor = M.anchor()
    win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      row = anchor.row,
      col = anchor.col,
      width = M.width,
      height = M.height,
      style = "minimal",
      focusable = false,
      noautocmd = true,
      zindex = 50,
    })
    vim.wo[win].winhighlight = "NormalFloat:AiKlammerAvatar"
  end
  M.poke()
  render()
  start_ticking()
  return win
end

function M.set_mood(new_mood)
  set_mood(new_mood)
  render()
end

function M.mood()
  return mood
end

function M.hide()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  if M.is_open() then
    vim.api.nvim_win_close(win, true)
  end
  win = nil
end

--- The cell the cursor sits in, counted across the whole editor.
local function cursor_col()
  return vim.fn.win_screenpos(0)[2] + vim.fn.wincol() - 1
end

local group = vim.api.nvim_create_augroup("AiKlammerAvatar", { clear = true })
vim.api.nvim_create_autocmd("VimResized", { group = group, callback = reposition })
-- Cheap enough per keystroke: render only runs when the gaze actually changes.
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = group,
  callback = function()
    if M.is_open() then
      M.poke()
      M.look(M.gaze_for(cursor_col(), vim.o.columns))
    end
  end,
})
vim.api.nvim_create_autocmd({ "InsertEnter", "CmdlineEnter", "FocusGained" }, {
  group = group,
  callback = function()
    if M.is_open() then
      M.poke()
    end
  end,
})

return M
