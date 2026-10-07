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
  ai = {
    -- a module name under ai_klammer.providers.*, or your own table with a
    -- stream(messages, config, on_chunk, on_done) function
    provider = "claude",
    -- nil = the provider's own default model, same for url below
    model = nil,
    url = nil,
    -- nil = read the provider's env var. A function is called when needed, a
    -- plain string is a key sitting in your dotfiles and health will say so.
    api_key = nil,
    max_tokens = 1024,
    -- the Klammer's manners; override to change its voice
    system = "You are the Klammer, an ASCII paperclip in the corner of a Neovim window. "
      .. "You are genuinely helpful and faintly condescending about it. "
      .. "Answer in at most six sentences of plain prose, no headings, no bullet lists. "
      .. "If the code is fine, say so in one sentence instead of inventing work.",
    -- lines above and below the cursor when nothing is selected and no function is found
    context_lines = 30,
    -- the Klammer refuses to read more than this in one go
    max_lines = 400,
  },
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
    ai = { config.ai, "table" },
    ["ai.provider"] = {
      config.ai.provider,
      function(provider)
        return type(provider) == "string" or (type(provider) == "table" and type(provider.stream) == "function")
      end,
      "a module name or a table with a stream function",
    },
    ["ai.model"] = { config.ai.model, "string", true },
    ["ai.url"] = { config.ai.url, "string", true },
    ["ai.api_key"] = { config.ai.api_key, { "string", "function" }, true },
    ["ai.max_tokens"] = { config.ai.max_tokens, "number" },
    ["ai.system"] = { config.ai.system, "string" },
    ["ai.context_lines"] = { config.ai.context_lines, "number" },
    ["ai.max_lines"] = { config.ai.max_lines, "number" },
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
