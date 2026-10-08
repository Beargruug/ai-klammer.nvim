Hier ist die überarbeitete Aufgabenliste mit dem neuen Namen. Repo heißt ai-klammer.nvim, das Lua-Modul ai_klammer, der Befehl bleibt kurz :Klammer. Die übrigen Annahmen von vorher gelten weiter: Neovim 0.10, Soloprojekt in der Freizeit, englisches README, die claude-CLI als Standard.

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
│   └── providers/ (shared.lua, claude.lua, anthropic.lua, openai.lua)
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
Phase 2: KI-Anbindung, v0.2 (ca. 2 Wochen) — erledigt
 [ ] providers/ollama.lua — gestrichen, lokale Modelle sind hier nicht gewollt. Wieder aufnehmen, falls jemand danach fragt.
 [x] ai.provider nimmt einen Modulnamen oder eine eigene Tabelle mit stream(), eigene Provider also direkt aus der Plugin-Config
 [ ] providers/init.lua mit Interface — übersprungen, ai.resolve() ist der ganze Vertrag. Kommt mit dem zweiten gebündelten Provider in Phase 3.
 [x] Sprechblase wächst beim Streamen mit, <Esc> bricht über :kill() ab
 [x] context/buffer.lua: Visual-Auswahl, sonst umschließende Funktion, sonst ±30 Zeilen um den Cursor
 [x] Umschließende Funktion über vim.treesitter, Fallback auf ±30 Zeilen wenn kein Parser da ist
 [x] :Klammer als range-Befehl registrieren, damit :'<,'>Klammer explain direkt funktioniert
 [x] :Klammer ask (per vim.ui.input) und :Klammer explain: markierte Funktion erklären
 [x] Keymap-Vorschlag im README, z. B. visual <leader>ke auf :Klammer explain
 [x] Erklärung streamt in die Sprechblase, Dateiname, Filetype und Zeilenbereich in den Prompt
 [x] Leere Auswahl oder zu großer Block (Default ca. 400 Zeilen): Klammer-Spruch statt Request
 [x] System-Prompt mit Persönlichkeit, konfigurierbar über ai.system
 [x] Trigger-Button „Ja“ startet die passende KI-Analyse, Diagnostics schicken die Fehlertexte mit
 [x] Healthcheck erweitern: Provider ladbar, Kommando auf dem PATH, API-Key vorhanden
 [x] Freundliche Fehlermeldung im Klammer-Ton, wenn kein Provider läuft
 [x] tests/test_ai.lua: NDJSON-Parser, Kontextauswahl, mitwachsende Sprechblase
Phase 3: Weitere Provider, v0.3 (ca. 1–2 Wochen) — erledigt
 [x] providers/anthropic.lua mit SSE-Streaming, vorgezogen
 [x] providers/claude.lua über die claude-CLI, nutzt das vorhandene Claude-Code-Login, kein API-Key
 [x] API-Keys aus Umgebungsvariable oder Funktion, Healthcheck warnt bei Klartext-Keys
 [x] ai.url und ai.model sind optional, jeder Provider kennt seine eigenen Defaults
 [x] Healthcheck prüft provider.command auf dem PATH, nicht mehr curl fest verdrahtet
 [x] providers/openai.lua mit konfigurierbarer base_url für kompatible APIs — deckt OpenAI, Groq, OpenRouter, llama.cpp und LM Studio ab
 [x] Gemeinsamen SSE-Parser aus anthropic.lua herausziehen, sobald openai.lua ihn auch braucht — providers/shared.lua, mit openai.lua als zweitem Aufrufer fällig geworden. Enthält auch Key-Lookup und den Subprozess-Pump, die alle drei Provider teilen.
 [ ] providers/init.lua mit Interface — bleibt übersprungen, auch mit drei Providern reicht ai.resolve() plus shared.lua
 [ ] Bestätigung vor dem ersten Senden an einen Cloud-Provider — vertagt auf Phase 4, :Klammer project macht sie nötig. Die Konfiguration ist bis dahin die Zustimmung.
 [ ] API-Key liegt in argv und ist in `ps` sichtbar, siehe ponytail-Kommentar in anthropic.lua und openai.lua — bekannte Decke, nur auf Mehrbenutzer-Maschinen ein Problem
 [ ] Persönlichkeitsmodi herablassend, hilfsbereit, passiv-aggressiv — gestrichen, ai.system ist schon ein freies Textfeld. Drei Presets wären Config für etwas, das man hintippen kann.
 [x] context.source landet im Prompt, damit „nearby“ nicht als abgeschnittener Code gemeldet wird
 [x] CHANGELOG.md angelegt, aus den beiden Tag-Messages
 [x] README nennt beide CI-Checks, nicht nur nvim -l
Phase 4: Projektkontext, v0.4 (ca. 2–3 Wochen)
 context/search.lua: Schlüsselwörter extrahieren, rg --json, Treffer ranken
 Token-Budget, Default ca. 6000 Tokens
 Projektübersicht über git ls-files, gekürzt
 context/lsp.lua: Dokumentsymbole und Diagnostics
 Blockliste für sensible Dateien (.env, *.pem, *secret*, *.key), standardmäßig aktiv
 :Klammer project <Frage>
 Optional: Embeddings, Cache in stdpath("cache") .. "/ai_klammer/"
Daueraufgaben
 Nach jedem Release ein neues GIF für das neue Feature
 Spruchvorschläge der Community über Issues annehmen
 CHANGELOG.md pflegen — angelegt, Unreleased-Abschnitt bei jedem Feature nachziehen
