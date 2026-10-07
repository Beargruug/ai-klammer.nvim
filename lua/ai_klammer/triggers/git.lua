local M = {}

M.name = "git"
M.events = { "BufWritePost" }

--- "3 files changed, 412 insertions(+), 18 deletions(-)" -> 430
function M.changed_lines(shortstat)
  local total = 0
  for count in shortstat:gmatch("(%d+) [id]") do
    total = total + tonumber(count)
  end
  return total
end

function M.check(buf, config, done)
  local file = vim.api.nvim_buf_get_name(buf)
  local dir = vim.fs.dirname(file)
  if file == "" or vim.fn.isdirectory(dir) == 0 then
    return done(nil)
  end
  vim.system({ "git", "diff", "--shortstat", "HEAD" }, { cwd = dir, text = true }, function(result)
    if result.code ~= 0 then
      return done(nil)
    end
    local total = M.changed_lines(result.stdout or "")
    done(total >= config.git_lines and total or nil)
  end)
end

return M
