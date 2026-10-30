# ai-klammer.nvim

An ASCII paperclip that lives in the corner of your editor and has opinions about your code.

> **Disclaimer:** Fan homage, not affiliated with Microsoft. No relation to Clippy,
> Office, or any Microsoft product or trademark.

```
 __    ╭──────────────────────────────────────╮
/  \   │ It looks like you're writing a       │
|  |   │ regular expression. Would you like   │
@  @   │ to have two problems?                │
|  |   │                                      │
|| |/  │ [Y]es   [N]o   Ne[v]er again         │
|| ||  ╰──────────────────────────────────────╯
|\_/|
\___/
```

It greets you when Neovim starts, fades the greeting after three seconds, then stays in the
corner blinking until you send it away. The greeting never takes your cursor.

Status: v0.4.0. It watches, it comments, it explains the function you just highlighted, and it
answers questions about the whole repository through Claude, the Anthropic API, or anything
that speaks OpenAI. It asks before sending anything, and it will not read your `.env`. Every so
often it says something of no use to anybody at all.

## Requirements

- Neovim 0.10+
- For the AI bits: the [`claude`](https://claude.com/claude-code) CLI, or `curl` and an API key
  for Anthropic or any OpenAI-compatible endpoint
- `git` for the big-diff trigger (optional)

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "Beargruug/ai-klammer.nvim", opts = { annoyance = 2 } }
```

Local development:

```lua
{ dir = "~/personal/ai-klammer.nvim", opts = {} }
```

## Configuration

```lua
require("ai_klammer").setup({
  annoyance = 2, -- 0 = silent, 1 = 15 min, 2 = 5 min, 3 = 1 min between quips,
                 -- and how often it says something with no point to it at all
  language = nil, -- "en" | "de", nil detects from v:lang
  animate = true, -- quips are typed in and the Klammer hops when it speaks
  ignore_filetypes = { "help", "qf", "netrw", "oil", "lazy", "mason", "gitcommit", "TelescopePrompt" },
  git_lines = 300, -- changed lines against HEAD before the Klammer says something
  diagnostics_count = 5, -- errors in the buffer before the Klammer says something
  ai = {
    provider = "claude", -- "claude", "anthropic", "openai", or your own table
    model = nil, -- nil = the provider's own default, same for url
    url = nil, -- base URL, for a proxy or any OpenAI-compatible server
    api_key = nil, -- nil = the provider's env var; a function is called when needed
    max_tokens = 1024,
    system = "...", -- the Klammer's manners, override to change its voice
    context_lines = 30, -- lines around the cursor when nothing else is found
    max_lines = 400, -- more than this and it refuses to read
    project_budget = 6000, -- rough token ceiling for :Klammer project
    blocklist = { ".env", "*.pem", "*secret*", ... }, -- files it never reads
    redact = true, -- strip recognisable API keys out of the code before sending
    consent = nil, -- nil asks once and remembers; true accepts up front
  },
})
```

## Using Claude

The default. If you have [Claude Code](https://claude.com/claude-code) installed and signed in,
there is nothing to configure — no API key, it goes through your existing subscription:

```lua
{ "Beargruug/ai-klammer.nvim", opts = {} }
```

`model` defaults to `"sonnet"`; set it to `"opus"`, `"haiku"` or a full model name if you'd
rather. The Klammer runs `claude --print` with its own system prompt and every file, shell and
agent tool switched off, so it answers and nothing else.

Or go through the API with a key:

```lua
{ "Beargruug/ai-klammer.nvim", opts = { ai = { provider = "anthropic" } } }
```

The key comes from `ANTHROPIC_API_KEY`. If it lives somewhere better than your shell profile,
hand over a function — it is called per request, so nothing is kept in your config:

```lua
ai = {
  provider = "anthropic",
  api_key = function()
    return vim.trim(vim.fn.system({ "op", "read", "op://Private/anthropic/key" }))
  end,
}
```

A plain string works too, and `:checkhealth ai_klammer` will tell you it is a bad idea.

> Either way the selected code leaves your machine when you ask a question. See
> [What it will not send](#what-it-will-not-send).

## Using OpenAI, or anything that speaks like it

```lua
{ "Beargruug/ai-klammer.nvim", opts = { ai = { provider = "openai" } } }
```

The key comes from `OPENAI_API_KEY`, or from `api_key` as a function, exactly as above. `url`
is the base URL including the version segment, so the same provider reaches anything with a
`/chat/completions` endpoint:

```lua
-- Groq
ai = { provider = "openai", url = "https://api.groq.com/openai/v1", model = "llama-3.3-70b-versatile" }

-- OpenRouter
ai = { provider = "openai", url = "https://openrouter.ai/api/v1", model = "anthropic/claude-sonnet-4.5" }

-- llama.cpp or LM Studio on your own machine, where the key is ignored
ai = { provider = "openai", url = "http://127.0.0.1:1234/v1", api_key = "none" }
```

## Bring your own AI

`ai.provider` is either the name of a bundled provider (`"claude"`, `"anthropic"`, `"openai"`)
or a table you pass in. Anything with a `stream` function will do, so the Klammer never has to know which
model, API or SDK you use:

```lua
require("ai_klammer").setup({
  ai = {
    provider = {
      --- @param messages table   { { role = "system"|"user", content = string }, ... }
      --- @param config table     the resolved config, so ai.model and ai.url are yours to use
      --- @param on_chunk fun(text: string)  append to the bubble; safe from any thread
      --- @param on_done fun(err: string|nil)  nil means it went fine
      --- @return table|nil  anything with :kill(), so closing the bubble cuts the answer off
      stream = function(messages, config, on_chunk, on_done)
        return vim.system({ "my-llm", "--model", config.ai.model }, {
          stdin = vim.json.encode(messages),
          stdout = function(_, data) if data then on_chunk(data) end end,
        }, function(result) on_done(result.code ~= 0 and result.stderr or nil) end)
      end,
    },
  },
})
```

`on_chunk` and `on_done` are already wrapped in `vim.schedule`, so call them from wherever you
like. Return `nil` if your provider cannot be cancelled; closing the bubble then just drops the
rest of the answer.
A table without a `stream` function is rejected in `setup()`, not at the first question.

## Asking it things

`:Klammer explain` explains the current selection. With no selection it finds the function
around your cursor with Treesitter, and falls back to the lines nearby. The answer streams into
the bubble in the corner and your cursor stays where it is, so you can keep working while it
talks. `:Klammer focus` goes into the bubble to scroll back or copy from it, and `q` or `<Esc>`
in there closes it and puts you back. `:Klammer close` does the same from anywhere. Closing an
answer that is still coming cuts it off mid-sentence and kills the request.

```lua
vim.keymap.set({ "n", "v" }, "<leader>ke", ":Klammer explain<CR>", { silent = true })
vim.keymap.set({ "n", "v" }, "<leader>ka", ":Klammer ask ", {})
vim.keymap.set("n", "<leader>kf", "<cmd>Klammer focus<CR>")
vim.keymap.set("n", "<leader>kc", "<cmd>Klammer close<CR>")
```

In visual mode `:Klammer explain` becomes `:'<,'>Klammer explain` on its own, so the selection
is what gets sent.

## Asking about the whole project

`:Klammer project where is the bubble drawn` searches the repository instead of the buffer.
It pulls the content words out of your question, hands them to `ripgrep`, and sends the model
the files that matched the most of them, best first, up to `ai.project_budget` tokens — plus
one line naming the directories in the repo so it knows what it is looking at.

```
:Klammer project why does the consent prompt fire twice
```

Without a question it prompts for one. `ripgrep` has to be on your `PATH`; `:checkhealth
ai_klammer` will say if it is not. The blocklist and redaction apply to search hits exactly
as they do to the current buffer, so a match inside `.env` never leaves the machine.

Ranking is "how many different keywords does this file contain", not "how many lines match",
or the changelog would outrank the code for every question.

## What it will not send

The Klammer talks to a model, so your code leaves your machine when you ask it something.
Three things limit that, all on by default.

**It asks once.** Before the first request ever, the Klammer asks whether your code may be
sent, and remembers the answer. `[N]o` declines this one question and it will ask again;
`Ne[v]er again` turns the AI features off for good, until `:Klammer reset`. Set
`ai.consent = true` to skip the question entirely.

**It never reads certain files.** Anything matching `ai.blocklist` — `.env`, `*.pem`, `*.key`,
`*secret*`, `id_rsa*`, `~/.ssh/*`, `~/.aws/*` and friends — is refused, by the commands *and*
by the triggers, so no bubble ever appears there offering to help. It stays quiet rather than
announcing the refusal, because "I won't read that" tells anyone watching your screen that the
file is worth reading. Globs without a slash match the file name; globs with one match the
whole path.

**It strips keys out of what it does send.** `ai.redact` removes recognisable credentials —
private key blocks, `sk-…`, `ghp_…`, `AKIA…`, `xox…`, and `password = "…"`-style assignments —
from the code before it goes anywhere. It matches known prefixes only, never entropy, because
a false positive would quietly mangle the code you asked about.

API keys are passed to `curl` in a `0600` file rather than on the command line, so they do not
show up in `ps`.

None of this makes it safe to point the Klammer at a machine full of other people's secrets.
It narrows the obvious accidents.

## Triggers

| Trigger       | When                                                          |
| ------------- | ------------------------------------------------------------- |
| `regex`       | A regex-looking literal under the cursor on `CursorHold`       |
| `git`         | `git diff --shortstat HEAD` over `git_lines` on save           |
| `diagnostics` | `diagnostics_count` errors or more in the buffer               |
| `idle`        | Nothing at all — every so often it just says something useless |

In the bubble: `y`/`j` yes, `n` no, `v`/`w` never again for that trigger, `q`/`<Esc>` to dismiss.

`idle` is the exception. It checks nothing, it has nothing to offer, and the remark is of no use
to anybody — that is the feature. Its bubble has no buttons, never takes your cursor, and fades
after four seconds. It never reads your code, so there is nothing it could send. It does know
what time it is and what language the file is in, so half the time, when there is something to
say about that, it says that instead: past midnight, Monday morning, Friday after three, the
weekend, a session over two hours, or YAML. The startup greeting works the same way. How often it happens comes from `annoyance`, and it keeps its own
half-hour cooldown on top, so a joke can never crowd out a trigger that had a real point to make.

## Faces

Between bubbles it keeps a face, and the face keeps up with you. It blinks at odd moments,
sometimes twice. Its eyes follow the cursor across the editor (`◐  ◐` / `◑  ◑`). It smiles at
a save with no errors, winces when the error count goes up, jumps at a thirty-line paste, and
falls asleep after five minutes alone, waking with a start when you come back. When it has
something to say it hops and types the quip in; `animate = false` stops both. No bubble, no
cooldown, and it never reads your code. See `:help ai-klammer-faces`.

## Memory

It remembers you between sessions. It introduces itself the first time, marks the tenth session
and other round numbers, notices when you were gone for days, suspects your config when you
restart within ten minutes, keeps score of how often you said no, and never opens with
yesterday's greeting. Counts and timestamps only, kept in its state file next to the "never
again" choices. `:Klammer reset` does not touch it; delete the file to make it forget. See
`:help ai-klammer-memory`.

## Commands

| Command                   | Description                                             |
| ------------------------- | ------------------------------------------------------- |
| `:Klammer hello`          | Say hello                                                |
| `:Klammer show`           | Bring the paperclip back                                 |
| `:Klammer hide`           | Send it away for this session                            |
| `:Klammer focus`          | Go into the bubble to scroll or copy; `q` comes back     |
| `:Klammer close`          | Close the bubble, cancelling an answer still coming      |
| `:Klammer reset`          | Forget every "never again" and the cooldown              |
| `:[range]Klammer explain` | Explain the selection, the function, or the lines nearby |
| `:[range]Klammer ask [q]` | Ask anything about that code; prompts without `q`        |
| `:Klammer project [q]`    | Ask about the whole repository; ripgrep finds the files  |

Answering a bubble closes the bubble only — the paperclip stays. `annoyance = 0` keeps it off
entirely, greeting included. Saying yes to a trigger now asks the model about it.

## Highlights

`AiKlammerAvatar`, `AiKlammerBubble`, `AiKlammerButton` — all linked with `default`, override freely.

## Tests

Both of these run in CI, so run both before pushing:

```sh
for t in tests/test_*.lua; do nvim -l "$t" || break; done
stylua --check .
```

## License

MIT
