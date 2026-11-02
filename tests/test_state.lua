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

-- Regression: once every trigger had a timestamp of its own, the shared clock
-- was never read, so regex spoke up a minute after git.
state.reset()
state.mark("regex", 0)
state.mark("git", 21 * 60)
assert(not state.can_fire("regex", 300, 300, 22 * 60), "git fired a minute ago, so regex waits")
assert(state.can_fire("regex", 300, 300, 26 * 60), "and speaks once the shared cooldown is over")
-- The jokes keep their own, longer clock on top of the shared one.
state.mark("idle", 0)
assert(not state.can_fire("idle", 1800, 300, 27 * 60), "idle waits half an hour since the last joke")
assert(state.can_fire("idle", 1800, 300, 30 * 60), "and no longer")

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
