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

--- Run git, and hand its output to `callback` on the main loop, nil if it failed.
local function git(args, cwd, callback)
  vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      callback(result.code == 0 and result.stdout or nil)
    end)
  end)
end

--- What a yes sends: the same diff the trigger counted, against HEAD across
--- the whole repository, minus every file `blocked` refuses. Filtered by file
--- before git is asked for the patch, so a changed .env never reaches the
--- Klammer at all, let alone the model. A --stat header comes first, so the
--- model still sees every file when the patch has to be cut short.
--- @param dir string any directory inside the repository
--- @param blocked fun(path: string): boolean given the absolute path
--- @param done fun(diff: string|nil) nil when there is nothing it may show
function M.diff(dir, blocked, done)
  git({ "rev-parse", "--show-toplevel" }, dir, function(top)
    if not top then
      return done(nil)
    end
    top = vim.trim(top)
    -- -z, or git quotes unusual file names and the blocklist never matches them.
    git({ "diff", "--name-only", "-z", "HEAD" }, top, function(names)
      local files = {}
      for name in (names or ""):gmatch("[^%z]+") do
        if not blocked(top .. "/" .. name) then
          table.insert(files, name)
        end
      end
      if #files == 0 then
        return done(nil)
      end
      git(vim.list_extend({ "diff", "--stat", "--patch", "HEAD", "--" }, files), top, done)
    end)
  end)
end

return M
