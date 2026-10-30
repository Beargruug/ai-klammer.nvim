vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local avatar = require("ai_klammer.ui.avatar")
local reactions = require("ai_klammer.reactions")
local config = require("ai_klammer.config").setup()

reactions.setup(config)
local win = avatar.show("neutral")
local function eyes()
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 3, 4, false)[1]
end

local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_exec_autocmds("BufEnter", { buffer = buf })

-- A big paste or undo makes it jump.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(("x\n"):rep(30), "\n"))
vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
assert(eyes() == "O  O ", "thirty lines at once is startling")

-- More errors than a moment ago.
local ns = vim.api.nvim_create_namespace("test_reactions")
local error = { lnum = 0, col = 0, message = "nope", severity = vim.diagnostic.severity.ERROR }
vim.diagnostic.set(ns, buf, { error })
assert(eyes() == ">  < ", "a new error gets a wince")

-- Saving with errors gets nothing; saving clean gets a smile.
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf })
assert(eyes() ~= "^  ^ ", "no praise with an error still in the buffer")
vim.diagnostic.reset(ns, buf)
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf })
assert(eyes() == "^  ^ ", "a clean save earns a smile")

-- annoyance = 0 means the Klammer is off, faces included.
reactions.setup(require("ai_klammer.config").setup({ annoyance = 0 }))
assert(#vim.api.nvim_get_autocmds({ group = "AiKlammerReactions" }) == 0, "not a single autocmd")

avatar.hide()
print("ok")
