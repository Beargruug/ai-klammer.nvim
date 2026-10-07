local M = {}

M.name = "claude"
M.command = "claude"
M.model = "sonnet"

--- Claude Code can read, write and run things. The Klammer wants prose, and a
--- bubble sitting silent while an agent explores the repo looks broken.
M.no_tools = {
  "Task",
  "Bash",
  "Edit",
  "Write",
  "NotebookEdit",
  "Read",
  "Glob",
  "Grep",
  "WebSearch",
  "WebFetch",
  "Skill",
  "ToolSearch",
}

--- The CLI prints NDJSON. Text arrives as content_block_delta events; the final
--- "result" line carries failures, which do not show up in the exit code.
--- @return table chunks { content, done, error }
--- @return string rest the unterminated tail, for the next read
function M.parse(buffer)
  local lines = vim.split(buffer, "\n", { plain = true })
  local rest = table.remove(lines)
  local chunks = {}
  for _, line in ipairs(lines) do
    local ok, object = pcall(vim.json.decode, line)
    if ok and type(object) == "table" then
      local event = object.type == "stream_event" and object.event or nil
      local delta = event and event.type == "content_block_delta" and event.delta or nil
      chunks[#chunks + 1] = {
        content = (delta and delta.text) or "",
        done = object.type == "result",
        error = (object.type == "result" and object.is_error and (object.result or object.subtype)) or nil,
      }
    end
  end
  return chunks, rest
end

function M.stream(messages, config, on_chunk, on_done)
  local system, prompt = nil, {}
  for _, message in ipairs(messages) do
    if message.role == "system" then
      system = message.content
    else
      prompt[#prompt + 1] = message.content
    end
  end

  local command = {
    M.command,
    "--print",
    "--output-format",
    "stream-json",
    "--include-partial-messages",
    "--verbose",
    "--model",
    config.ai.model or M.model,
    -- Replacing the system prompt rather than appending drops the whole Claude
    -- Code preamble, which is most of the latency and all of the agent manners.
    "--system-prompt",
    system or "",
    "--strict-mcp-config",
    "--restricted",
    -- Variadic, so it goes last.
    "--disallowed-tools",
  }
  vim.list_extend(command, M.no_tools)

  local buffer = ""
  local failed
  return vim.system(command, {
    text = true,
    stdin = table.concat(prompt, "\n\n"),
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
      failed = vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr) or ("claude exited with " .. result.code)
    end
    on_done(failed)
  end)
end

return M
