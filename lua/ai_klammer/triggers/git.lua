local M = {}

M.name = "git"
M.events = { "BufWritePost" }

--- Lines added and removed, from `git diff --numstat -z`, minus every file
--- `blocked` refuses. A binary file counts nothing; a rename counts under
--- its new name, which -z prints after an empty path and the old one.
--- @param numstat string
--- @param blocked fun(path: string): boolean given the path from the root
--- @return integer
function M.changed_lines(numstat, blocked)
  local fields = vim.split(numstat, "\0", { plain = true })
  local total, index = 0, 1
  while index <= #fields do
    local added, deleted, path = fields[index]:match("^(%S+)\t(%S+)\t(.*)$")
    index = index + 1
    if added then
      if path == "" then
        path, index = fields[index + 1] or "", index + 2
      end
      if not blocked(path) then
        total = total + (tonumber(added) or 0) + (tonumber(deleted) or 0)
      end
    end
  end
  return total
end

--- Run git, and hand its output to `callback` on the main loop, nil if it failed.
local function git(args, cwd, callback)
  vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      callback(result.code == 0 and result.stdout or nil)
    end)
  end)
end

--- Big enough to speak up about, counting only what a yes would send: a
--- large .env change is not a diff the Klammer could ever explain. From the
--- top of the repository, because that is where git's paths start.
function M.check(buf, config, done)
  local file = vim.api.nvim_buf_get_name(buf)
  local dir = vim.fs.dirname(file)
  if file == "" or vim.fn.isdirectory(dir) == 0 then
    return done(nil)
  end
  local secrets = require("ai_klammer.context.secrets")
  git({ "rev-parse", "--show-toplevel" }, dir, function(top)
    if not top then
      return done(nil)
    end
    top = vim.trim(top)
    git({ "diff", "--numstat", "-z", "HEAD" }, top, function(numstat)
      local total = M.changed_lines(numstat or "", function(path)
        return secrets.blocked(top .. "/" .. path, config)
      end)
      done(total >= config.git_lines and total or nil)
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
