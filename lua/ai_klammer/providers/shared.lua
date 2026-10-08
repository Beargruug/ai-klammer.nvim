local M = {}

--- Newline-delimited JSON with the SSE `data: ` prefix stripped when it is
--- there, which covers the Anthropic and OpenAI streams as well as the plain
--- NDJSON the claude CLI prints. Half-written lines, `event:` lines and the
--- `[DONE]` sentinel drop out on their own: they do not decode.
--- @return table objects decoded, in order
--- @return string rest the unterminated tail, for the next read
function M.events(buffer)
  local lines = vim.split(buffer, "\n", { plain = true })
  local rest = table.remove(lines)
  local objects = {}
  for _, line in ipairs(lines) do
    -- luanil, or every JSON null arrives as vim.NIL and reads as a real value.
    local ok, object = pcall(vim.json.decode, line:match("^data: (.+)$") or line, { luanil = { object = true } })
    if ok and type(object) == "table" then
      objects[#objects + 1] = object
    end
  end
  return objects, rest
end

--- A string key would sit in a dotfile, so the env var is the default and a
--- function is the way to pull one out of a password manager.
function M.key(provider, config)
  local source = config.ai.api_key
  if type(source) == "function" then
    return source()
  end
  return source or os.getenv(provider.env)
end

--- Pump a streaming subprocess: gather stdout, hand whole lines to the
--- provider's parse, forward the text, keep the first failure. Both APIs and
--- the CLI report errors inside the stream as often as in the exit code.
--- @param parse fun(buffer: string): table, string
--- @return table the vim.system handle, so the caller can :kill() it
function M.run(command, stdin, parse, on_chunk, on_done)
  local buffer = ""
  local failed
  return vim.system(command, {
    text = true,
    stdin = stdin,
    stdout = function(_, data)
      if not data then
        return
      end
      local chunks
      chunks, buffer = parse(buffer .. data)
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
      failed = vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr)
        or (command[1] .. " exited with " .. result.code)
    end
    on_done(failed)
  end)
end

return M
