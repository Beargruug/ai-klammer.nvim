vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local state = require("ai_klammer.state")
state.path = vim.fn.tempname() .. "/ai_klammer.json"
state.reset()

assert(state.can_fire("regex", 60), "first fire should be allowed")
state.mark("regex")
assert(not state.can_fire("regex", 60), "cooldown should block the next one")
assert(not state.can_fire("git", 60), "cooldown is shared across triggers")
assert(state.can_fire("git", 0), "zero cooldown lets everything through")
assert(not state.can_fire("git", math.huge), "annoyance 0 blocks everything")

assert(not state.is_never("git"), "nothing silenced yet")
state.set_never("git")
assert(state.is_never("git"), "never again should stick")
assert(not state.can_fire("git", 0), "silenced triggers never fire")
assert(vim.deep_equal(state.silenced(), { "git" }), "silenced list should report git")

assert(vim.fn.filereadable(state.path) == 1, "state should be written to disk")
assert(vim.json.decode(table.concat(vim.fn.readfile(state.path), "\n")).never.git == true, "never list persists")

state.reset()
assert(not state.is_never("git"), "reset should forget everything")

print("ok")
