local M = {}

M.config = require("ai_klammer.config").setup()

function M.setup(opts)
  -- LuaJIT starts from the same seed every time, so without this the Klammer
  -- greets you with the same line every single morning.
  math.randomseed(vim.uv.hrtime())
  M.config = require("ai_klammer.config").setup(opts)
  require("ai_klammer.triggers").setup(M.config)
  require("ai_klammer.reactions").setup(M.config)
  local group = vim.api.nvim_create_augroup("AiKlammerMemory", { clear = true })
  if M.config.annoyance > 0 then
    -- Off means off: a silenced Klammer does not keep notes on you either.
    require("ai_klammer.memory").start()
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      callback = function()
        require("ai_klammer.memory").touch()
      end,
    })
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
  local memory = require("ai_klammer.memory")
  local quip = memory.greeting(memory.start(), vim.bo.filetype)
  require("ai_klammer.ui.bubble").show(quip, {
    animate = M.config.animate,
    focus = false,
    timeout = 3000,
  })
end

function M.hello()
  require("ai_klammer.ui.bubble").show("It looks like you're writing code. Would you like help?", {
    animate = M.config.animate,
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
--- While an answer is still on screen, a question without a range is about
--- that answer; a range always means new code.
--- @param question? string
--- @param range? table { first, last }
function M.ask(question, range)
  asked("Klammer: ", question, function(input)
    local ai = require("ai_klammer.ai")
    if not range and ai.can_follow_up() then
      if ai.fits(input, M.config) then
        return ai.follow_up(input, M.config)
      end
      -- Too long to send again: a new conversation, about the code at hand.
      ai.forget()
      vim.notify(
        "ai-klammer: that conversation got too long, starting a new one",
        vim.log.levels.INFO,
        { title = "ai-klammer" }
      )
    end
    ai.run(input, range, M.config)
  end)
end

--- Copy the last whole answer into a register: the one named, or the one a
--- plain y would use, so 'clipboard' is respected.
--- @param register? string
function M.yank(register)
  local last = require("ai_klammer.ai").last
  if not last then
    return vim.notify("ai-klammer: no answer to yank yet", vim.log.levels.INFO, { title = "ai-klammer" })
  end
  register = (register and register ~= "") and register or vim.v.register
  vim.fn.setreg(register, last.answer)
  vim.notify(("ai-klammer: answer yanked into %s"):format(register), vim.log.levels.INFO, { title = "ai-klammer" })
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

--- Go into the bubble, to scroll back through an answer or copy from it.
function M.focus()
  if not require("ai_klammer.ui.bubble").focus() then
    vim.notify("ai-klammer: nothing to focus, no bubble is open", vim.log.levels.INFO, { title = "ai-klammer" })
  end
end

--- Close the bubble, cancelling an answer still on its way. The Klammer stays.
function M.close()
  require("ai_klammer.ai").forget()
  require("ai_klammer.ui.bubble").close()
end

--- Show the last answer again, for when it faded before you were done.
function M.last()
  if not require("ai_klammer.ai").reopen(nil, M.config) then
    vim.notify("ai-klammer: no answer to show yet", vim.log.levels.INFO, { title = "ai-klammer" })
  end
end

--- Pick one of the last answers and show it again.
function M.history()
  local ai = require("ai_klammer.ai")
  if #ai.history == 0 then
    return vim.notify("ai-klammer: no answers yet", vim.log.levels.INFO, { title = "ai-klammer" })
  end
  vim.ui.select(ai.history, { prompt = "Klammer, show again: ", format_item = ai.label }, function(entry)
    if entry then
      ai.reopen(entry, M.config)
    end
  end)
end

--- Send the Klammer away until :Klammer show or the next trigger.
function M.hide()
  require("ai_klammer.ai").forget()
  require("ai_klammer.ui.bubble").close()
  require("ai_klammer.ui.avatar").hide()
end

--- Forget every "never again" and let the Klammer speak up again.
function M.reset()
  require("ai_klammer.state").reset()
  vim.notify("ai-klammer: back to full strength", vim.log.levels.INFO, { title = "ai-klammer" })
end

return M
