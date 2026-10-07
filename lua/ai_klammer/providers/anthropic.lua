local M = {}

M.name = "anthropic"
M.command = "curl"
M.url = "https://api.anthropic.com"
M.model = "claude-sonnet-4-5"
M.env = "ANTHROPIC_API_KEY"

--- A string key would sit in a dotfile, so the env var is the default and a
--- function is the way to pull one out of a password manager.
function M.key(config)
  local source = config.ai.api_key
  if type(source) == "function" then
    return source()
  end
  return source or os.getenv(M.env)
end

--- Server-sent events: "data: {...}" lines, "event: ..." lines to ignore, and a
--- plain JSON body when the request is rejected before the stream starts.
--- @return table chunks { content, done, error }
--- @return string rest the unterminated tail, for the next read
function M.parse(buffer)
  local lines = vim.split(buffer, "\n", { plain = true })
  local rest = table.remove(lines)
  local chunks = {}
  for _, line in ipairs(lines) do
    local ok, object = pcall(vim.json.decode, line:match("^data: (.+)$") or line)
    if ok and type(object) == "table" then
      chunks[#chunks + 1] = {
        content = (object.delta and object.delta.text) or "",
        done = object.type == "message_stop",
        error = object.error and (object.error.message or object.error.type),
      }
    end
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

  local buffer = ""
  local failed
  -- ponytail: the key rides in argv, so it shows up in `ps` for this user.
  -- Move it into a 0600 curl --config file if that ever matters.
  return vim.system({
    "curl",
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
  }, {
    text = true,
    stdin = body(messages, config),
    stdout = function(_, data)
      if not data then
        return
      end
      local chunks
      chunks, buffer = M.parse(buffer .. data)
      for _, chunk in ipairs(chunks) do
        if chunk.error then
          failed = chunk.error
        elseif chunk.content ~= "" then
          on_chunk(chunk.content)
        end
      end
    end,
  }, function(result)
    if not failed and result.code ~= 0 then
      failed = vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr) or ("curl exited with " .. result.code)
    end
    on_done(failed)
  end)
end

return M
