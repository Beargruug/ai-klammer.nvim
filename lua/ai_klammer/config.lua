local M = {}

M.defaults = {
  -- 0 = silent, 3 = maximum Klammer
  annoyance = 2,
  -- nil = detect from v:lang
  language = nil,
}

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  vim.validate({
    annoyance = { config.annoyance, "number" },
    language = { config.language, "string", true },
  })
  assert(
    config.annoyance >= 0 and config.annoyance <= 3,
    "ai_klammer: annoyance must be between 0 and 3, got " .. tostring(config.annoyance)
  )

  config.language = config.language or (vim.v.lang:find("^de") and "de" or "en")

  return config
end

return M
