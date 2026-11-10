vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local config = require("ai_klammer.config")

local defaults = config.setup()
assert(defaults.annoyance == 2, "default annoyance should be 2")

assert(config.setup({ annoyance = 0 }).annoyance == 0, "annoyance should be overridable")
assert(config.defaults.annoyance == 2, "setup must not mutate defaults")

assert(defaults.animate == true, "quips are typed in by default")
assert(config.setup({ animate = false }).animate == false, "and that can be turned off")
assert(not pcall(config.setup, { animate = "slowly" }), "animate is a yes or a no")

assert(defaults.ai.answer_timeout == "auto", "answers fade after a reading time by default")
assert(config.setup({ ai = { answer_timeout = false } }).ai.answer_timeout == false, "or stay")
assert(config.setup({ ai = { answer_timeout = 5000 } }).ai.answer_timeout == 5000, "or go after a fixed time")
assert(not pcall(config.setup, { ai = { answer_timeout = "soon" } }), "and nothing else")
assert(config.setup({ ai = { words_per_minute = 120 } }).ai.words_per_minute == 120, "slow readers set their pace")
assert(not pcall(config.setup, { ai = { words_per_minute = 0 } }), "a reading speed of zero never ends")

assert(defaults.ai.request_timeout == 60000, "a minute of silence before giving up")
assert(config.setup({ ai = { request_timeout = false } }).ai.request_timeout == false, "or never")
assert(not pcall(config.setup, { ai = { request_timeout = -1 } }), "but not a negative minute")

assert(defaults.ai.brief == false, "answers are not squeezed by default")
assert(not pcall(config.setup, { ai = { brief = "very" } }), "brief is a yes or a no")

assert(not pcall(config.setup, { annoyance = "loud" }), "wrong type should fail")
assert(not pcall(config.setup, { annoyance = 9 }), "out of range should fail")

-- Regression: a blocklist of your own replaced the defaults, so adding one
-- glob quietly unblocked .env, keys and ~/.ssh. Yours now go on top.
local defaults = require("ai_klammer.config").defaults.ai.blocklist
local added = require("ai_klammer.config").setup({ ai = { blocklist = { "*.sqlite" } } }).ai.blocklist
assert(vim.tbl_contains(added, "*.sqlite"), "your glob is in")
assert(vim.tbl_contains(added, ".env"), "and the defaults are still there: " .. vim.inspect(added))
assert(#added == #defaults + 1, "each of them once")
-- "!glob" takes a default back out, for code that happens to be called secrets.lua.
local dropped = require("ai_klammer.config").setup({ ai = { blocklist = { "!*secret*", "*.sqlite" } } }).ai.blocklist
assert(not vim.tbl_contains(dropped, "*secret*"), "a ! takes a default out")
assert(not vim.tbl_contains(dropped, "!*secret*"), "and is not a glob itself")
assert(vim.tbl_contains(dropped, ".env") and vim.tbl_contains(dropped, "*.sqlite"), "the rest stays")
assert(#require("ai_klammer.config").setup().ai.blocklist == #defaults, "no blocklist of your own, the defaults")
assert(#defaults == 20, "and setup leaves the defaults table alone")

print("ok")
