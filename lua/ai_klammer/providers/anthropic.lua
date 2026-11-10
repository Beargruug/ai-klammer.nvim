local shared = require("ai_klammer.providers.shared")

local M = {}

M.name = "anthropic"
M.command = "curl"
M.url = "https://api.anthropic.com"
M.model = "claude-sonnet-5-5"
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
      -- message_delta says why it stopped; max_tokens means mid-sentence.
      cut = object.delta ~= nil and object.delta.stop_reason == "max_tokens",
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

  return shared.curl({
    url = (config.ai.url or M.url) .. "/v1/messages",
    headers = {
      "content-type: application/json",
      "anthropic-version: 2023-06-01",
      "x-api-key: " .. key,
    },
    body = body(messages, config),
    parse = M.parse,
    secret = key,
  }, on_chunk, on_done)
end

return M
