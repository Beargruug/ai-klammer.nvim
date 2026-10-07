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

function M.show(mood)
  require("ai_klammer.ui.avatar").show(mood)
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
