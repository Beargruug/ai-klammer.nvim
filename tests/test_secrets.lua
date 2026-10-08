vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local secrets = require("ai_klammer.context.secrets")
local config = require("ai_klammer.config").setup()

-- Files the Klammer must never read, however it is asked.
for _, path in ipairs({
  ".env",
  "/home/u/project/.env",
  "/home/u/project/.env.local",
  "deploy/server.pem",
  "private.key",
  "terraform.tfvars",
  "config/secrets.yml",
  "/home/u/.aws/credentials",
  "/home/u/.ssh/id_rsa",
  "/home/u/.gnupg/trustdb.gpg",
  ".netrc",
}) do
  assert(secrets.blocked(path, config), path .. " must be blocked")
end

-- ...and ordinary files that must stay readable, or the plugin is useless.
for _, path in ipairs({
  "init.lua",
  "/home/u/project/lua/ai_klammer/ai.lua",
  "README.md",
  "keyboard.css",
  "monkey.py",
}) do
  assert(not secrets.blocked(path, config), path .. " must not be blocked")
end

-- "*secret*" is unanchored, so matching it against the whole path would block
-- every file in a directory that merely sounds interesting.
assert(not secrets.blocked("/home/u/secret-santa-app/init.lua", config), "a directory name must not block its files")
assert(secrets.blocked("/home/u/secret-santa-app/my-secrets.txt", config), "the file name itself still counts")

-- An unsaved buffer has no path and is not a secret.
assert(not secrets.blocked("", config), "an unsaved buffer is readable")

-- Keys pasted into an otherwise ordinary file still must not leave.
local redacted, hit = secrets.redact([[
local client = OpenAI.new("sk-proj-abcdefghijklmnopqrstuvwxyz0123456789")
local aws = "AKIAIOSFODNN7EXAMPLE"
password = "hunter2-hunter2-hunter2"
]])
assert(hit, "something was redacted")
assert(not redacted:find("sk%-proj%-abcdef"), "the OpenAI key is gone")
assert(not redacted:find("AKIAIOSFODNN7EXAMPLE"), "the AWS key id is gone")
assert(not redacted:find("hunter2"), "the assigned password is gone")
assert(redacted:find("OpenAI.new", 1, true), "the surrounding code survives")

local pem =
  secrets.redact("before\n-----BEGIN RSA PRIVATE KEY-----\nMIIEpQIBAAKC\nAQ==\n-----END RSA PRIVATE KEY-----\nafter")
assert(not pem:find("MIIEpQIBAAKC"), "the whole key block goes, not just its header")
assert(pem:find("before", 1, true) and pem:find("after", 1, true), "and nothing around it")

-- False positives are worse than the leak: a mangled explanation is useless.
local code = [[
local key = i + 1
local keyboard = "qwerty"
local token = next(tokens)
for key, value in pairs(config) do print(key, value) end
]]
local untouched, any = secrets.redact(code)
assert(untouched == code and not any, "ordinary code is left alone:\n" .. untouched)

-- The trigger path matters more than the command path: a bubble that appears
-- on its own in a .env file is one keystroke away from sending it.
local triggers = require("ai_klammer.triggers")
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/.env")
vim.bo[buf].buftype = ""
assert(triggers.ignored(buf, config), "the Klammer never speaks up in a secrets file")

local ok_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(ok_buf, vim.fn.tempname() .. "/init.lua")
vim.bo[ok_buf].buftype = ""
assert(not triggers.ignored(ok_buf, config), "but it still speaks up in ordinary files")

print("ok")
