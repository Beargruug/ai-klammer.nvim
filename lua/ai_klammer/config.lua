local M = {}

M.defaults = {
  -- 0 = silent, 3 = maximum Klammer
  annoyance = 2,
  -- nil = detect from v:lang
  language = nil,
  -- quips are typed in and the Klammer hops when it speaks; false for neither
  animate = true,
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
    -- "claude", "anthropic", "openai", or your own table with a
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
    -- rough token ceiling for the search hits :Klammer project sends
    project_budget = 6000,
    -- files the Klammer never reads, and never admits to not reading. Globs
    -- without a slash match the file name, globs with one match the path.
    blocklist = {
      ".env",
      ".env.*",
      "*.pem",
      "*.key",
      "*.p12",
      "*.pfx",
      "*.kdbx",
      "*.tfvars",
      "*secret*",
      "*credential*",
      "id_rsa*",
      "id_ecdsa*",
      "id_ed25519*",
      ".netrc",
      ".npmrc",
      ".pypirc",
      ".htpasswd",
      "*/.ssh/*",
      "*/.aws/*",
      "*/.gnupg/*",
    },
    -- strip recognisable API keys out of the code before it is sent
    redact = true,
    -- nil asks once before the first request and remembers the answer;
    -- true accepts up front, for a config that should never prompt
    consent = nil,
    -- how long a finished answer stays: "auto" is long enough to read it,
    -- a number is milliseconds, false keeps it until you close it
    answer_timeout = "auto",
    -- how fast you read, for answer_timeout = "auto": lower stays longer
    words_per_minute = 240,
    -- rough token ceiling for a conversation; a follow-up past it starts a new one
    max_context = 150000,
  },
}

-- seconds between quips, indexed by annoyance level
M.cooldowns = { [0] = math.huge, 15 * 60, 5 * 60, 60 }

-- chance per CursorHold that the Klammer says something useless, by annoyance.
-- ponytail: no separate switch, turning jokes off means turning the Klammer
-- down. Add ai.jokes if somebody wants the triggers loud and the jokes gone.
M.chances = { [0] = 0, 0.02, 0.05, 0.12 }

--- vim.validate(name, value, validator, optional, message) from 0.11 on; the
--- table form 0.10 knows warns in :checkhealth vim.deprecated and goes in 1.0.
local function validate(name, value, validator, optional, message)
  if vim.fn.has("nvim-0.11") == 1 then
    return vim.validate(name, value, validator, optional, message)
  end
  vim.validate({ [name] = { value, validator, message or optional } })
end

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})

  validate("annoyance", config.annoyance, "number")
  validate("language", config.language, "string", true)
  validate("animate", config.animate, "boolean")
  validate("ignore_filetypes", config.ignore_filetypes, "table")
  validate("git_lines", config.git_lines, "number")
  validate("diagnostics_count", config.diagnostics_count, "number")
  validate("ai", config.ai, "table")
  validate("ai.provider", config.ai.provider, function(provider)
    return type(provider) == "string" or (type(provider) == "table" and type(provider.stream) == "function")
  end, false, "a module name or a table with a stream function")
  validate("ai.model", config.ai.model, "string", true)
  validate("ai.url", config.ai.url, "string", true)
  validate("ai.api_key", config.ai.api_key, { "string", "function" }, true)
  validate("ai.max_tokens", config.ai.max_tokens, "number")
  validate("ai.system", config.ai.system, "string")
  validate("ai.context_lines", config.ai.context_lines, "number")
  validate("ai.max_lines", config.ai.max_lines, "number")
  validate("ai.project_budget", config.ai.project_budget, "number")
  validate("ai.blocklist", config.ai.blocklist, "table")
  validate("ai.redact", config.ai.redact, "boolean")
  validate("ai.consent", config.ai.consent, "boolean", true)
  validate("ai.answer_timeout", config.ai.answer_timeout, function(timeout)
    return timeout == "auto" or timeout == false or (type(timeout) == "number" and timeout > 0)
  end, false, '"auto", milliseconds, or false')
  validate("ai.max_context", config.ai.max_context, function(limit)
    return type(limit) == "number" and limit > 0
  end, false, "a number of tokens above 0")
  validate("ai.words_per_minute", config.ai.words_per_minute, function(speed)
    return type(speed) == "number" and speed > 0
  end, false, "a number above 0")
  assert(
    config.annoyance >= 0 and config.annoyance <= 3,
    "ai_klammer: annoyance must be between 0 and 3, got " .. tostring(config.annoyance)
  )

  config.language = config.language or (vim.v.lang:find("^de") and "de" or "en")
  config.cooldown = M.cooldowns[config.annoyance]
  config.joke_chance = M.chances[config.annoyance]

  return config
end

return M
