local M = {}

function M.provider(config)
  local ai = config.ai
  local custom = type(ai.provider) ~= "string"
  vim.health.info("provider = " .. (custom and "a table from your config" or ai.provider))

  local provider = require("ai_klammer.ai").resolve(config)
  if not provider then
    return vim.health.error("cannot load provider " .. tostring(ai.provider))
  end
  if custom then
    return vim.health.ok("your provider is loaded; whether it works is between you and it")
  end

  local url = ai.url or provider.url
  local model = ai.model or provider.model
  vim.health.info(("model = %s, url = %s"):format(model or "the provider's own", url or "n/a, it runs a command"))
  if provider.command then
    if vim.fn.executable(provider.command) == 0 then
      return vim.health.error(
        ("%s not found on your PATH, so the %s provider cannot run"):format(provider.command, ai.provider)
      )
    end
    vim.health.ok(provider.command .. " found")
  end

  if provider.env then
    if type(ai.api_key) == "string" then
      vim.health.warn("ai.api_key is a plain string, so your key lives in your dotfiles; use " .. provider.env)
    end
    local ok, key = pcall(provider.key, config)
    if ok and key and key ~= "" then
      vim.health.ok("an API key is set, and your code will leave this machine when you ask it to")
    else
      vim.health.error(("no API key: export %s or set ai.api_key"):format(provider.env))
    end
  end
end

--- The Klammer is deliberately silent in a blocklisted file, which makes
--- "why does nothing happen here" impossible to diagnose without this.
function M.privacy(config, state)
  local consent = config.ai.consent
  if consent == nil then
    consent = state.consent()
  end
  if consent == false then
    vim.health.warn("you said never: no code is sent and the AI features stay off until :Klammer reset")
  elseif consent == true then
    vim.health.ok("sending your code is allowed; :Klammer reset to take it back")
  else
    vim.health.info("the Klammer will ask once before it sends anything")
  end

  vim.health.info(
    ("%d blocklist globs, redaction %s"):format(
      #config.ai.blocklist,
      config.ai.redact and "on" or "off, keys in your code will be sent as they are"
    )
  )
  local name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  if require("ai_klammer.context.secrets").blocked(name, config) then
    vim.health.warn("this buffer is blocklisted, so the Klammer ignores it on purpose")
  end
end

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
  M.provider(config)
  vim.health.info(("annoyance = %d, language = %s"):format(config.annoyance, config.language or "auto"))
  if config.annoyance == 0 then
    vim.health.warn("annoyance = 0, the Klammer will never show up")
  end

  local state = require("ai_klammer.state")
  M.privacy(config, state)

  vim.health.info("state file: " .. state.path)
  local silenced = state.silenced()
  if #silenced > 0 then
    vim.health.info("silenced triggers: " .. table.concat(silenced, ", "))
  end
end

return M
