local M = {}

M.name = "diagnostics"
M.events = { "CursorHold", "BufWritePost" }

function M.check(buf, config, done)
  local errors = #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
  done(errors >= config.diagnostics_count and errors or nil)
end

return M
