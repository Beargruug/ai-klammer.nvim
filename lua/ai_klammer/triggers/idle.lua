local M = {}

M.name = "idle"
M.events = { "CursorHold" }

--- Jokes get their own cooldown, far longer than the useful triggers share.
--- Without it the dice would win the shared cooldown nearly every time and
--- you would stop hearing about your regexes, which is the opposite of help.
M.cooldown = 30 * 60

--- Nothing is checked. That is the point: the Klammer has no observation to
--- make, it simply has something to say. Anything context-aware belongs in a
--- real trigger, where it can offer to do something about what it found.
function M.check(_, config, done)
  done(math.random() < config.joke_chance and 1 or nil)
end

return M
