vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local config = require("ai_klammer.config")

local defaults = config.setup()
assert(defaults.annoyance == 2, "default annoyance should be 2")
assert(defaults.language == "en" or defaults.language == "de", "language should be detected")

assert(config.setup({ annoyance = 0 }).annoyance == 0, "annoyance should be overridable")
assert(config.setup({ language = "de" }).language == "de", "language should be overridable")
assert(config.defaults.annoyance == 2, "setup must not mutate defaults")

assert(not pcall(config.setup, { annoyance = "loud" }), "wrong type should fail")
assert(not pcall(config.setup, { annoyance = 9 }), "out of range should fail")

print("ok")
