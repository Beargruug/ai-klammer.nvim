local M = {}

M.eyes = {
  neutral = "@  @ ",
  blink = "-  - ",
  thinking = "o  o ",
  annoyed = ">  < ",
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

local buf, win, timer
local mood = "neutral"

local function render(eyes)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines = {}
  for i, line in ipairs(body) do
    lines[i] = line or eyes
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

local function start_blinking()
  if timer then
    return
  end
  timer = vim.uv.new_timer()
  timer:start(4000, 4000, function()
    vim.schedule(function()
      if not M.is_open() then
        return
      end
      render(M.eyes.blink)
      vim.defer_fn(function()
        if M.is_open() then
          render(M.eyes[mood])
        end
      end, 150)
    end)
  end)
end

function M.is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.show(new_mood)
  mood = M.eyes[new_mood] and new_mood or mood
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
  render(M.eyes[mood])
  start_blinking()
  return win
end

function M.set_mood(new_mood)
  mood = M.eyes[new_mood] and new_mood or mood
  render(M.eyes[mood])
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

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("AiKlammerAvatar", { clear = true }),
  callback = reposition,
})

return M
