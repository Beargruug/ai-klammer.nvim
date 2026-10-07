if vim.g.loaded_ai_klammer then
  return
end
vim.g.loaded_ai_klammer = true

local subcommands = {
  hello = function()
    require("ai_klammer").hello()
  end,
}

vim.api.nvim_create_user_command("Klammer", function(args)
  local name = args.fargs[1] or "hello"
  local run = subcommands[name]
  if not run then
    vim.notify("Klammer: unknown subcommand " .. name, vim.log.levels.ERROR, { title = "ai-klammer" })
    return
  end
  run()
end, {
  nargs = "?",
  desc = "ai-klammer.nvim",
  complete = function(lead)
    return vim.tbl_filter(function(name)
      return vim.startswith(name, lead)
    end, vim.tbl_keys(subcommands))
  end,
})
