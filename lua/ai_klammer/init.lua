local M = {}

M.config = require("ai_klammer.config").setup()

function M.setup(opts)
  M.config = require("ai_klammer.config").setup(opts)
  require("ai_klammer.triggers").setup(M.config)
  if M.config.annoyance > 0 then
    if vim.v.vim_did_enter == 1 then
      M.greet()
    else
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          M.greet()
        end,
      })
    end
  end
  return M.config
end

--- Show up with a hello that fades on its own and never takes your cursor.
function M.greet()
  require("ai_klammer.ui.bubble").show(require("ai_klammer.quips").pick("greeting", M.config.language), {
    language = M.config.language,
    focus = false,
    timeout = 3000,
  })
end

function M.hello()
  require("ai_klammer.ui.bubble").show("It looks like you're writing code. Would you like help?", {
    language = M.config.language,
    buttons = true,
  })
end

function M.show()
  require("ai_klammer.ui.avatar").show()
end

--- Run `answer` on a question, asking for one when the command came without it.
local function asked(prompt, question, answer)
  if question and question ~= "" then
    return answer(question)
  end
  vim.ui.input({ prompt = prompt }, function(input)
    if input and input ~= "" then
      answer(input)
    end
  end)
end

--- Put a question to the Klammer about the code at hand. Prompts when none is given.
--- @param question? string
--- @param range? table { first, last }
function M.ask(question, range)
  asked("Klammer: ", question, function(input)
    require("ai_klammer.ai").run(input, range, M.config)
  end)
end

--- Put a question to the Klammer about the whole project rather than one buffer.
--- @param question? string
function M.project(question)
  asked("Klammer, about this project: ", question, function(input)
    require("ai_klammer.ai").project(input, M.config)
  end)
end

--- Explain the selection, or the function around the cursor when nothing is selected.
--- @param _ string? unused, keeps the subcommand signature
--- @param range? table { first, last }
function M.explain(_, range)
  local ai = require("ai_klammer.ai")
  ai.run(ai.questions.explain, range, M.config)
end

--- Send the Klammer away until :Klammer show or the next trigger.
function M.hide()
  require("ai_klammer.ui.bubble").close()
  require("ai_klammer.ui.avatar").hide()
end

--- Forget every "never again" and let the Klammer speak up again.
function M.reset()
  require("ai_klammer.state").reset()
  vim.notify("ai-klammer: back to full strength", vim.log.levels.INFO, { title = "ai-klammer" })
end

return M
