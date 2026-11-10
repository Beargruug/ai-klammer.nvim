local shared = require("ai_klammer.providers.shared")

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
  local objects, rest = shared.events(buffer)
  local chunks = {}
  for _, object in ipairs(objects) do
    local event = object.type == "stream_event" and object.event or nil
    local delta = event and event.type == "content_block_delta" and event.delta or nil
    chunks[#chunks + 1] = {
      content = (delta and delta.text) or "",
      done = object.type == "result",
      cut = event ~= nil and event.type == "message_delta" and (event.delta or {}).stop_reason == "max_tokens",
      error = (object.type == "result" and object.is_error and (object.result or object.subtype)) or nil,
    }
  end
  return chunks, rest
end

--- The CLI takes one prompt on stdin, not a list of turns. A single question
--- goes as it is; a conversation is spelled out turn by turn, or the model
--- would read its own earlier answer as something the user wrote.
--- @return string|nil system
--- @return string prompt
function M.prompt(messages)
  local system, turns = nil, {}
  for _, message in ipairs(messages) do
    if message.role == "system" then
      system = message.content
    else
      turns[#turns + 1] = message
    end
  end
  if #turns == 1 then
    return system, turns[1].content
  end
  local labels = { user = "User", assistant = "Assistant" }
  return system,
    table.concat(
      vim.tbl_map(function(turn)
        return (labels[turn.role] or turn.role) .. ": " .. turn.content
      end, turns),
      "\n\n"
    )
end

function M.stream(messages, config, on_chunk, on_done)
  local system, prompt = M.prompt(messages)

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

  return shared.run(command, prompt, M.parse, on_chunk, on_done)
end

return M
