local M = {}

M.config = require("ai_klammer.config").defaults

function M.setup(opts)
  M.config = require("ai_klammer.config").setup(opts)
  return M.config
end

function M.hello()
  vim.notify(
    ("It looks like you're writing code. Would you like help? (annoyance=%d, lang=%s)"):format(
      M.config.annoyance,
      M.config.language or "auto"
    ),
    vim.log.levels.INFO,
    { title = "ai-klammer" }
  )
end

return M
