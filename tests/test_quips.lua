vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local quips = require("ai_klammer.quips")

for _, language in ipairs({ "en", "de" }) do
  local set = require("ai_klammer.quips." .. language)
  for _, trigger in ipairs({ "greeting", "regex", "git", "diagnostics" }) do
    assert(#set[trigger] >= 10, language .. "/" .. trigger .. " needs at least 10 quips")
    for _, quip in ipairs(set[trigger]) do
      assert(#quip > 0 and not quip:find("%%[^d]"), "bad format string: " .. quip)
    end
  end
end

assert(quips.pick("regex", "klingon"), "unknown language falls back to English")
assert(quips.pick("nope", "en") == nil, "unknown trigger has no quip")

local counted = quips.pick("git", "en", 412)
assert(not counted:find("%%d"), "no raw placeholder should survive")

print("ok")
