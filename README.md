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

Status: v0.1, no AI yet. It watches, it comments, it can be told to never again.

## Requirements

- Neovim 0.10+
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
})
```

## Triggers

| Trigger       | When                                                           |
| ------------- | -------------------------------------------------------------- |
| `regex`       | A regex-looking literal under the cursor on `CursorHold`        |
| `git`         | `git diff --shortstat HEAD` over `git_lines` on save            |
| `diagnostics` | `diagnostics_count` errors or more in the buffer                |

In the bubble: `y`/`j` yes, `n` no, `v`/`w` never again for that trigger, `q`/`<Esc>` to dismiss.

## Commands

| Command          | Description                                     |
| ---------------- | ----------------------------------------------- |
| `:Klammer hello` | Say hello                                       |
| `:Klammer show`  | Bring the paperclip back                        |
| `:Klammer hide`  | Send it away for this session                   |
| `:Klammer reset` | Forget every "never again" and the cooldown     |

Answering a bubble closes the bubble only — the paperclip stays. `annoyance = 0` keeps it off
entirely, greeting included.

## Highlights

`AiKlammerAvatar`, `AiKlammerBubble`, `AiKlammerButton` — all linked with `default`, override freely.

## Tests

```sh
for t in tests/test_*.lua; do nvim -l "$t"; done
```

## License

MIT
