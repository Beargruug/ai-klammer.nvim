vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local config = require("ai_klammer.config")

local defaults = config.setup()
assert(defaults.annoyance == 2, "default annoyance should be 2")
assert(defaults.language == "en" or defaults.language == "de", "language should be detected")

assert(config.setup({ annoyance = 0 }).annoyance == 0, "annoyance should be overridable")
assert(config.setup({ language = "de" }).language == "de", "language should be overridable")
assert(config.defaults.annoyance == 2, "setup must not mutate defaults")

assert(defaults.animate == true, "quips are typed in by default")
assert(config.setup({ animate = false }).animate == false, "and that can be turned off")
assert(not pcall(config.setup, { animate = "slowly" }), "animate is a yes or a no")

assert(not pcall(config.setup, { annoyance = "loud" }), "wrong type should fail")
assert(not pcall(config.setup, { annoyance = 9 }), "out of range should fail")

print("ok")
