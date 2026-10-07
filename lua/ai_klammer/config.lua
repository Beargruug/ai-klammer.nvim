local M = {}

M.defaults = {
  -- 0 = silent, 3 = maximum Klammer
  annoyance = 2,
  -- nil = detect from v:lang
  language = nil,
  -- buffers the Klammer keeps out of
  ignore_filetypes = {
    "help",
    "qf",
    "netrw",
    "oil",
    "lazy",
    "mason",
    "gitcommit",
    "TelescopePrompt",
    "ai_klammer",
  },
  -- git diff --shortstat threshold, in changed lines
  git_lines = 300,
  -- how many errors in the buffer before the Klammer comments
  diagnostics_count = 5,
}

-- seconds between quips, indexed by annoyance level
M.cooldowns = { [0] = math.huge, 15 * 60, 5 * 60, 60 }

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  vim.validate({
    annoyance = { config.annoyance, "number" },
    language = { config.language, "string", true },
    ignore_filetypes = { config.ignore_filetypes, "table" },
    git_lines = { config.git_lines, "number" },
    diagnostics_count = { config.diagnostics_count, "number" },
  })
  assert(
    config.annoyance >= 0 and config.annoyance <= 3,
    "ai_klammer: annoyance must be between 0 and 3, got " .. tostring(config.annoyance)
  )

  config.language = config.language or (vim.v.lang:find("^de") and "de" or "en")
  config.cooldown = M.cooldowns[config.annoyance]

  return config
end

return M
