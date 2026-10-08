local M = {}

--- The innermost function, method or class around the cursor, via Treesitter.
--- @return number|nil first 1-based, inclusive
--- @return number|nil last
function M.enclosing(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not ok or not parser then
    return nil
  end
  -- get_node reads the last tree, so make sure there is one even without highlighting.
  parser:parse(true)
  local node = vim.treesitter.get_node({ bufnr = buf })
  while node do
    if node:type():find("function") or node:type():find("method") or node:type():find("class") then
      local first, _, last = node:range()
      return first + 1, last + 1
    end
    node = node:parent()
  end
end

--- Selection first, then the enclosing function, then whatever is near the cursor.
--- @param range? table { first, last } from a command range
--- @return table|nil context { text, first, last, name, filetype, source }
--- @return string|nil reason "blocked", "empty" or "too_big", with the line count
--- @return number|nil count
function M.grab(buf, range, config)
  -- Every question about code routes through here, so this is the one place
  -- the blocklist has to hold. "blocked" is answered with silence upstream.
  local path = vim.api.nvim_buf_get_name(buf)
  if require("ai_klammer.context.secrets").blocked(path, config) then
    return nil, "blocked"
  end

  local first, last, source
  if range then
    first, last, source = range[1], range[2], "selection"
  else
    first, last = M.enclosing(buf)
    source = first and "function" or nil
  end
  if not first then
    local cursor = vim.api.nvim_win_get_cursor(0)[1]
    first = math.max(1, cursor - config.ai.context_lines)
    last = math.min(vim.api.nvim_buf_line_count(buf), cursor + config.ai.context_lines)
    source = "nearby"
  end

  last = math.min(last, vim.api.nvim_buf_line_count(buf))
  if last - first + 1 > config.ai.max_lines then
    return nil, "too_big", last - first + 1
  end

  local text = table.concat(vim.api.nvim_buf_get_lines(buf, first - 1, last, false), "\n")
  if vim.trim(text) == "" then
    return nil, "empty"
  end
  if config.ai.redact then
    text = require("ai_klammer.context.secrets").redact(text)
  end

  return {
    text = text,
    first = first,
    last = last,
    name = path ~= "" and vim.fn.fnamemodify(path, ":.") or "an unsaved buffer",
    filetype = vim.bo[buf].filetype,
    source = source,
  }
end

return M
