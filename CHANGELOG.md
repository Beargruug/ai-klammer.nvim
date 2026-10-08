# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] — the Klammer talks to anything

### Added

- `openai` provider, with `ai.url` as the base URL, so OpenAI, Groq, OpenRouter,
  llama.cpp and LM Studio all work without any plugin changes
- The prompt now says where the code came from — a selection, a whole function,
  or an arbitrary slice around the cursor — so the model stops reporting the
  Klammer's own clipping as a bug

### Changed

- Line splitting, API key lookup and subprocess streaming moved into
  `providers/shared.lua`, shared by all three providers

### Fixed

- A JSON `null` decoded to `vim.NIL` and read as a real value, which ended an
  OpenAI stream on its first token

## [0.2.0] — the Klammer reads your code

### Added

- `:Klammer explain` and `:Klammer ask`, answers streaming into the bubble
- Context: visual selection, else the enclosing function via Treesitter, else
  the lines around the cursor
- Providers: `claude` (the CLI, uses your Claude Code sign-in) and `anthropic`
  (API key from env or a function). `ai.provider` also takes your own table
- `<Esc>` kills a running request; empty or oversized ranges get a remark, not a call

### Changed

- Trigger "yes" now runs the matching analysis instead of an apology

## [0.1.0] — the Klammer, no AI

An ASCII paperclip in the corner with opinions and no help to offer.

### Added

- Avatar with blink/think/annoyed moods, bubble with `[Y]es`/`[N]o`/`Ne[v]er again`
- Triggers: regex literals on `CursorHold`, big git diffs on save, LSP error count
- Quips in English and German, cooldown and per-trigger "never again" in state
- `:Klammer hello|show|hide|reset`, `:checkhealth ai_klammer`

[unreleased]: https://github.com/Beargruug/ai-klammer.nvim/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/Beargruug/ai-klammer.nvim/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Beargruug/ai-klammer.nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Beargruug/ai-klammer.nvim/releases/tag/v0.1.0
