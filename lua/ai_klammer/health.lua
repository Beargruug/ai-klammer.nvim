local M = {}

function M.check()
  vim.health.start("ai-klammer.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim 0.10+ required")
  end

  if vim.fn.executable("git") == 1 then
    vim.health.ok("git found, the big-diff trigger works")
  else
    vim.health.warn("git not found, the big-diff trigger stays quiet")
  end

  if vim.fn.executable("rg") == 1 then
    vim.health.ok("rg found")
  else
    vim.health.warn("rg not found, needed for project context in v0.4")
  end

  local config = require("ai_klammer").config
  vim.health.info(("annoyance = %d, language = %s"):format(config.annoyance, config.language or "auto"))
  if config.annoyance == 0 then
    vim.health.warn("annoyance = 0, the Klammer will never show up")
  end

  local state = require("ai_klammer.state")
  vim.health.info("state file: " .. state.path)
  local silenced = state.silenced()
  if #silenced > 0 then
    vim.health.info("silenced triggers: " .. table.concat(silenced, ", "))
  end
end

return M
