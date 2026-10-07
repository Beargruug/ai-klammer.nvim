Hier ist die überarbeitete Aufgabenliste mit dem neuen Namen. Repo heißt ai-klammer.nvim, das Lua-Modul ai_klammer, der Befehl bleibt kurz :Klammer. Die übrigen Annahmen von vorher gelten weiter: Neovim 0.10, Soloprojekt in der Freizeit, englisches README, Ollama als Standard.

Projektstruktur
ai-klammer.nvim/
├── plugin/ai_klammer.lua      -- registriert :Klammer
├── lua/ai_klammer/
│   ├── init.lua               -- setup(), öffentliche API
│   ├── config.lua
│   ├── health.lua             -- :checkhealth ai_klammer
│   ├── state.lua
│   ├── ui/        (avatar.lua, bubble.lua)
│   ├── triggers/  (init.lua, git.lua, regex.lua, diagnostics.lua)
│   ├── quips/     (de.lua, en.lua)
│   ├── context/   (buffer.lua, search.lua, lsp.lua)
│   └── providers/ (init.lua, ollama.lua, openai.lua, anthropic.lua)
├── doc/ai-klammer.txt
└── tests/
Phase 0: Fundament (ca. 1 Abend)
 Auf GitHub prüfen, ob ai-klammer.nvim frei ist, und das leere Repo sofort anlegen
 Ordnerstruktur wie oben anlegen, MIT-Lizenz hinzufügen
 .stylua.toml und .luarc.json einrichten
 Lokal per lazy.nvim einbinden: { dir = "~/dev/ai-klammer.nvim", opts = {} }
 init.lua mit setup(opts) und config.lua mit Defaults und vim.validate anlegen
 :Klammer mit Unterbefehlen anlegen (zunächst nur hello)
 Disclaimer ins README: „Fan homage, not affiliated with Microsoft“
Phase 1: MVP ohne KI, v0.1 (ca. 2–3 Wochen)

UI

 Eigene ASCII-Büroklammer entwerfen, mindestens 4 Frames: neutral, blinzeln, nachdenken, genervt
 ui/avatar.lua: Fenster unten rechts, focusable = false, berücksichtigt cmdheight und laststatus
 Animation mit vim.uv.new_timer(), Timer beim Schließen sauber stoppen
 Bei VimResized neu positionieren
 ui/bubble.lua: Sprechblase über der Figur, Breite passt sich an, filetype = markdown
 Buttons [J]a [N]ein [Nie wieder] als buffer-lokale Keymaps, dazu q/<Esc>
 Highlight-Gruppen AiKlammerBubble, AiKlammerAvatar, AiKlammerButton mit default = true

Zustand und Trigger

 state.lua: Cooldown und „Nie wieder“-Liste als JSON in stdpath("data") .. "/ai_klammer.json"
 annoyance-Stufe 0–3 in der Config umsetzen
 triggers/init.lua: CursorHold und BufWritePost mit Debounce und Filetype-Blacklist, Autocmd-Gruppe AiKlammer
 triggers/git.lua: git diff --shortstat asynchron beim Speichern, Default-Schwelle 300 Zeilen
 triggers/regex.lua: einfache Heuristik zuerst, Treesitter später
 triggers/diagnostics.lua: Spruch ab einer bestimmten Fehlerzahl

Inhalt

 quips/en.lua und quips/de.lua mit mindestens 10 Sprüchen pro Trigger
 Ein paar Sprüche mit dem Klammer-Doppelsinn einbauen (Klammern im Code vs. Büroklammer)
 Sprache automatisch über v:lang, per Config überschreibbar

Qualität und Release

 health.lua für :checkhealth ai_klammer: Neovim-Version, git, rg
 Tests mit mini.test für Config, Cooldown und Spruchauswahl
 GitHub Action: Tests auf stable + nightly, stylua --check
 doc/ai-klammer.txt mit Installation, Config und Befehlen
 Demo-GIF mit vhs: Regex tippen, Klammer erscheint, „Nie wieder“ drücken
 README: GIF ganz oben, darunter Installations-Snippet:
lua
  { "deinname/ai-klammer.nvim", opts = { annoyance = 2 } }
 Tag v0.1.0 setzen und auf r/neovim posten
Phase 2: KI-Anbindung, v0.2 (ca. 2 Wochen)
 providers/init.lua: Interface stream(messages, opts, on_chunk, on_done)
 providers/ollama.lua mit NDJSON-Streaming
 Sprechblase wächst beim Streamen mit, <Esc> bricht über :kill() ab
 context/buffer.lua: Visual-Auswahl oder ±30 Zeilen um den Cursor
 :Klammer ask (per vim.ui.input) und :Klammer explain (Visual Mode)
 System-Prompt mit Persönlichkeit, konfigurierbar
 Trigger-Button „Ja“ startet die passende KI-Analyse
 Healthcheck erweitern: Ollama erreichbar, Modell vorhanden?
 Freundliche Fehlermeldung im Klammer-Ton, wenn kein Provider läuft
Phase 3: Weitere Provider, v0.3 (ca. 1–2 Wochen)
 Gemeinsamen SSE-Parser schreiben
 providers/openai.lua mit konfigurierbarer base_url für kompatible APIs
 providers/anthropic.lua
 API-Keys nur aus Umgebungsvariable oder Funktion, Healthcheck warnt bei Klartext-Keys
 Bestätigung vor dem ersten Senden an einen Cloud-Provider
 Persönlichkeitsmodi herablassend, hilfsbereit, passiv-aggressiv
Phase 4: Projektkontext, v0.4 (ca. 2–3 Wochen)
 context/search.lua: Schlüsselwörter extrahieren, rg --json, Treffer ranken
 Token-Budget, Default ca. 6000 Tokens
 Projektübersicht über git ls-files, gekürzt
 context/lsp.lua: Dokumentsymbole und Diagnostics
 Blockliste für sensible Dateien (.env, *.pem, *secret*, *.key), standardmäßig aktiv
 :Klammer project <Frage>
 Optional: Embeddings über Ollama, Cache in stdpath("cache") .. "/ai_klammer/"
Daueraufgaben
 Nach jedem Release ein neues GIF für das neue Feature
 Spruchvorschläge der Community über Issues annehmen
 CHANGELOG.md pflegen
