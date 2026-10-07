# ai-klammer.nvim

An ASCII paperclip that lives in the corner of your editor and has opinions about your code.

> **Disclaimer:** Fan homage, not affiliated with Microsoft. No relation to Clippy,
> Office, or any Microsoft product or trademark.

Status: Phase 0. It says hello. That is all it does.

## Requirements

- Neovim 0.10+

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
  annoyance = 2, -- 0 = silent, 3 = maximum Klammer
  language = nil, -- "en" | "de", nil detects from v:lang
})
```

## Commands

| Command           | Description    |
| ----------------- | -------------- |
| `:Klammer hello`  | Say hello      |

## Tests

```sh
nvim -l tests/test_config.lua
```

## License

MIT
