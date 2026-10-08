local shared = require("ai_klammer.providers.shared")

local M = {}

M.name = "openai"
M.command = "curl"
--- The base URL carries the version segment, because every OpenAI-compatible
--- server puts its own path in front of /chat/completions.
M.url = "https://api.openai.com/v1"
M.model = "gpt-4o-mini"
M.env = "OPENAI_API_KEY"

function M.key(config)
  return shared.key(M, config)
end

--- Text arrives as choices[1].delta.content. A rejected request answers with a
--- plain JSON error body instead of a stream.
--- @return table chunks { content, done, error }
--- @return string rest the unterminated tail, for the next read
function M.parse(buffer)
  local objects, rest = shared.events(buffer)
  local chunks = {}
  for _, object in ipairs(objects) do
    local choice = (object.choices or {})[1] or {}
    chunks[#chunks + 1] = {
      content = (choice.delta and choice.delta.content) or "",
      done = choice.finish_reason ~= nil,
      error = object.error and (object.error.message or object.error.type),
    }
  end
  return chunks, rest
end

function M.stream(messages, config, on_chunk, on_done)
  local key = M.key(config)
  if not key or key == "" then
    return on_done("no API key: set " .. M.env .. " or ai.api_key")
  end

  local body = vim.json.encode({
    model = config.ai.model or M.model,
    -- The o-series wants max_completion_tokens, but max_tokens is what every
    -- compatible server understands. Swap it in ai.max_tokens's place if you
    -- ever point this at a reasoning model.
    max_tokens = config.ai.max_tokens,
    messages = messages,
    stream = true,
  })

  -- ponytail: the key rides in argv, so it shows up in `ps` for this user.
  -- Move it into a 0600 curl --config file if that ever matters.
  return shared.run({
    M.command,
    "-sS",
    "--no-buffer",
    "-X",
    "POST",
    (config.ai.url or M.url) .. "/chat/completions",
    "-H",
    "content-type: application/json",
    "-H",
    "authorization: Bearer " .. key,
    "--data-binary",
    "@-",
  }, body, M.parse, on_chunk, on_done)
end

return M
