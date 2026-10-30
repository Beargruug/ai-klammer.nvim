if vim.g.loaded_ai_klammer then
  return
end
vim.g.loaded_ai_klammer = true

local function highlights()
  vim.api.nvim_set_hl(0, "AiKlammerAvatar", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "AiKlammerBubble", { link = "NormalFloat", default = true })
  vim.api.nvim_set_hl(0, "AiKlammerButton", { link = "Question", default = true })
end

highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("AiKlammerHighlights", { clear = true }),
  callback = highlights,
})

local subcommands = { "hello", "show", "hide", "focus", "close", "reset", "ask", "explain", "project" }

vim.api.nvim_create_user_command("Klammer", function(args)
  local name = args.fargs[1] or "hello"
  if not vim.tbl_contains(subcommands, name) then
    vim.notify("Klammer: unknown subcommand " .. name, vim.log.levels.ERROR, { title = "ai-klammer" })
    return
  end
  local rest = table.concat(vim.list_slice(args.fargs, 2), " ")
  local range = args.range > 0 and { args.line1, args.line2 } or nil
  require("ai_klammer")[name](rest, range)
end, {
  nargs = "*",
  range = true,
  desc = "ai-klammer.nvim",
  complete = function(lead, line)
    -- Only the first word is a subcommand; the rest is a question in prose.
    if line:match("^%s*%S+%s+%S+%s") then
      return {}
    end
    return vim.tbl_filter(function(name)
      return vim.startswith(name, lead)
    end, subcommands)
  end,
})
