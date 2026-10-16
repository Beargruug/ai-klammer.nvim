# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `:Klammer project <question>` asks about the whole repository instead of one
  buffer: the content words of the question go to `ripgrep`, and the files that
  matched the most of them are sent, best first
- The prompt carries a one-line map of the repository by directory, so the model
  knows what kind of project it is looking at
- `ai.project_budget`, a rough token ceiling (default 6000) on how much of the
  search result is sent. `ripgrep` is now required for `project` and nothing else
- An `idle` trigger: every so often the Klammer says something of no use to
  anybody. No buttons, no cursor stolen, gone after four seconds, and it never
  reads your code, so there is nothing for it to send. How often comes from
  `annoyance`; it keeps a half-hour cooldown of its own so it cannot crowd out
  a trigger with something real to say

## [0.3.1] — the Klammer learns what not to read

### Security

- The Klammer no longer reads files matching `ai.blocklist` (`.env`, `*.pem`,
  `*secret*`, `~/.ssh/*` and friends). This applies to the triggers too, so no
  bubble appears in such a file offering help that would send it. The refusal
  is silent: announcing it would confirm the file is worth reading
- `ai.redact` strips recognisable credentials — private key blocks, `sk-…`,
  `ghp_…`, `AKIA…`, `xox…`, JWTs and long `password = "…"` values — out of the
  code before it is sent. Known prefixes only, no entropy guessing
- The Klammer asks once, before the very first request, whether your code may
  leave the machine, and remembers the answer. `Ne[v]er again` disables the AI
  features until `:Klammer reset`. `ai.consent = true` skips the prompt
- API keys are passed to `curl` through a `0600` file instead of argv, so they
  no longer show up in `ps`
- Any API key is scrubbed out of error messages before they reach the bubble

### Added

- `ai.send()`, so context that did not come from the current buffer can still
  be put to the model

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

[unreleased]: https://github.com/Beargruug/ai-klammer.nvim/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/Beargruug/ai-klammer.nvim/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Beargruug/ai-klammer.nvim/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Beargruug/ai-klammer.nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Beargruug/ai-klammer.nvim/releases/tag/v0.1.0
