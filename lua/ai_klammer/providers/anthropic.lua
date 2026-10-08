local shared = require("ai_klammer.providers.shared")

local M = {}

M.name = "anthropic"
M.command = "curl"
M.url = "https://api.anthropic.com"
M.model = "claude-sonnet-4-5"
M.env = "ANTHROPIC_API_KEY"

function M.key(config)
  return shared.key(M, config)
end

--- Text arrives as delta.text. A request rejected before the stream starts
--- answers with a plain JSON error body instead.
--- @return table chunks { content, done, error }
--- @return string rest the unterminated tail, for the next read
function M.parse(buffer)
  local objects, rest = shared.events(buffer)
  local chunks = {}
  for _, object in ipairs(objects) do
    chunks[#chunks + 1] = {
      content = (object.delta and object.delta.text) or "",
      done = object.type == "message_stop",
      error = object.error and (object.error.message or object.error.type),
    }
  end
  return chunks, rest
end

--- Anthropic wants the system prompt beside the messages, not inside them.
local function body(messages, config)
  local system, rest = nil, {}
  for _, message in ipairs(messages) do
    if message.role == "system" then
      system = message.content
    else
      rest[#rest + 1] = message
    end
  end
  return vim.json.encode({
    model = config.ai.model or M.model,
    max_tokens = config.ai.max_tokens,
    system = system,
    messages = rest,
    stream = true,
  })
end

function M.stream(messages, config, on_chunk, on_done)
  local key = M.key(config)
  if not key or key == "" then
    return on_done("no API key: set " .. M.env .. " or ai.api_key")
  end

  -- ponytail: the key rides in argv, so it shows up in `ps` for this user.
  -- Move it into a 0600 curl --config file if that ever matters.
  return shared.run({
    M.command,
    "-sS",
    "--no-buffer",
    "-X",
    "POST",
    (config.ai.url or M.url) .. "/v1/messages",
    "-H",
    "content-type: application/json",
    "-H",
    "anthropic-version: 2023-06-01",
    "-H",
    "x-api-key: " .. key,
    "--data-binary",
    "@-",
  }, body(messages, config), M.parse, on_chunk, on_done)
end

return M
