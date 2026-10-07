local M = {}

M.name = "regex"
M.events = { "CursorHold" }

--- Everything that looks like a string or /slash/ literal on the line.
local function literals(line)
  local out = {}
  for _, pattern in ipairs({ '"([^"]*)"', "'([^']*)'", "/([^/]+)/[gimsuxy]*" }) do
    for found in line:gmatch(pattern) do
      out[#out + 1] = found
    end
  end
  return out
end

-- ponytail: metacharacter count, no parsing. Swap in Treesitter if it misfires.
function M.looks_like_regex(line)
  for _, literal in ipairs(literals(line)) do
    local _, meta = literal:gsub("[%(%)%[%]%*%+%?%^%$\\|{}]", "")
    if meta >= 4 then
      return meta
    end
  end
  return nil
end

function M.check(_, _, done)
  done(M.looks_like_regex(vim.api.nvim_get_current_line()))
end

return M
