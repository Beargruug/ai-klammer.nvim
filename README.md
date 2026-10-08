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

Status: v0.3. It watches, it comments, it explains the function you just highlighted, and it
does it through Claude, the Anthropic API, or anything that speaks OpenAI.

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
  annoyance = 2, -- 0 = silent, 1 = 15 min, 2 = 5 min, 3 = 1 min between quips
  language = nil, -- "en" | "de", nil detects from v:lang
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

> Either way the selected code leaves your machine when you ask a question. The Klammer will
> not ask again after you configure it — that is what configuring it means.

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
      --- @return table|nil  anything with :kill(), so <Esc> can cut the answer off
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
like. Return `nil` if your provider cannot be cancelled; `<Esc>` then just closes the bubble.
A table without a `stream` function is rejected in `setup()`, not at the first question.

## Asking it things

`:Klammer explain` explains the current selection. With no selection it finds the function
around your cursor with Treesitter, and falls back to the lines nearby. The answer streams into
the bubble; `<Esc>` or `q` cuts it off mid-sentence and kills the request.

```lua
vim.keymap.set({ "n", "v" }, "<leader>ke", ":Klammer explain<CR>", { silent = true })
vim.keymap.set({ "n", "v" }, "<leader>ka", ":Klammer ask ", {})
```

In visual mode `:Klammer explain` becomes `:'<,'>Klammer explain` on its own, so the selection
is what gets sent.

## Triggers

| Trigger       | When                                                           |
| ------------- | -------------------------------------------------------------- |
| `regex`       | A regex-looking literal under the cursor on `CursorHold`        |
| `git`         | `git diff --shortstat HEAD` over `git_lines` on save            |
| `diagnostics` | `diagnostics_count` errors or more in the buffer                |

In the bubble: `y`/`j` yes, `n` no, `v`/`w` never again for that trigger, `q`/`<Esc>` to dismiss.

## Commands

| Command                   | Description                                             |
| ------------------------- | ------------------------------------------------------- |
| `:Klammer hello`          | Say hello                                                |
| `:Klammer show`           | Bring the paperclip back                                 |
| `:Klammer hide`           | Send it away for this session                            |
| `:Klammer reset`          | Forget every "never again" and the cooldown              |
| `:[range]Klammer explain` | Explain the selection, the function, or the lines nearby |
| `:[range]Klammer ask [q]` | Ask anything about that code; prompts without `q`        |

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
