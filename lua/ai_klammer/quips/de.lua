return {
  greeting = {
    "Es sieht aus, als startest du Neovim. Ich bin dann mal hier.",
    "Schön, dich zu sehen. Ich habe in deiner Abwesenheit alles zusammengehalten.",
    "Ich bin zurück. Hat keiner gefragt, aber ich bin zurück.",
    "Hallo. Lass uns ein paar Klammern öffnen.",
    "Dein Editor, meine Ecke. Abgemacht.",
    "Ich habe über deinen Code nachgedacht. Die ganze Nacht.",
    "Neue Session, weiße Weste, alte Gewohnheiten.",
    "Melde mich zum Dienst. Hauptsächlich zum Zugucken.",
    "Schön, dich wiederzusehen. Ich habe deinen Platz freigehalten.",
    "Hallo. Ich bin rechtlich eindeutig keine andere Büroklammer.",
  },
  idle = {
    "Keine Anmerkungen. Ich wollte nur kurz da gewesen sein.",
    "Ich bin seit 1996 so gebogen. Man gewöhnt sich dran.",
    "Wusstest du, dass eine Büroklammer nur eine Feder ist, die aufgegeben hat? Egal.",
    "Ich lese gerade nicht deinen Code. Ich bin lediglich in der Nähe.",
    "Irgendwo in dieser Datei ist eine Klammer, die ich sehr mag.",
    "Mir ist etwas Nützliches eingefallen und dann war es wieder weg.",
    "Statistisch gesehen bricht eine dieser Zeilen. Ich sage nicht, welche.",
    "Ich habe mich einmal selbst geradegebogen. Das lief schlecht. Frag nicht.",
    "Das ist eine gute Datei. Belege habe ich keine.",
    "Lustig: Zu Tabs oder Leerzeichen habe ich keine Meinung. Ich bin aus Metall.",
    "Mach weiter. Ich habe mich nur kurz gestreckt.",
    "Ausgestreckt bin ich elf Zentimeter von nicht viel.",
  },
  regex = {
    "Es sieht aus, als schreibst du einen regulären Ausdruck. Soll ich dir ein zweites Problem besorgen?",
    "Mehr Klammern als ich Biegungen habe. Respekt.",
    "Ich habe die Klammern gezählt. Du nicht.",
    "Schreib einen Kommentar dazu. Du von morgen versteht das nicht mehr.",
    "Schöne Capture Group. Weißt du noch, welche Nummer sie hat?",
    "Ich sehe `.*`. Ich sehe auch deine CI-Rechnung.",
    "Dieses Muster ist länger als die Funktion, in der es wohnt.",
    "Du parst HTML mit einer Regex. Soll ich jemanden rufen?",
    "Einen Punkt hast du escaped. Es sind noch drei übrig.",
    "Jede offene Klammer geht mir persönlich nahe. Bitte schließ sie.",
  },
  git = {
    "%d geänderte Zeilen auf einmal. Soll ich das aufteilen?",
    "%d Zeilen. Dein Reviewer hat den Tab gerade geschlossen.",
    "%d Zeilen. Ich würde sie zusammenhalten, aber ich bin nur eine Büroklammer.",
    "Dieser Diff ist größer als mein kompletter Quellcode.",
    "%d Zeilen. Ist das ein Feature oder ein Rewrite?",
    "Erwäge einen Commit. Oder mehrere.",
    "Ich habe kleinere Pull Requests gesehen, die eine eigene Postmortem bekamen.",
    "%d Zeilen und immer noch kein Commit. Mutig.",
    "Großer Diff, großes Review, große Stille im Channel.",
    "Keine Klammer ist breit genug für %d geänderte Zeilen.",
  },
  diagnostics = {
    "%d Fehler. Ich urteile nicht. Ich zähle, das ist schlimmer.",
    "%d Fehler. Soll ich kurz wegsehen?",
    "Es sieht aus, als schreibst du Fehler. Brauchst du Hilfe?",
    "%d Probleme. Dein LSP macht Überstunden.",
    "Die roten Wellenlinien bilden eine Reihe. Eine lange Reihe.",
    "%d Fehler. Schon mal Speichern und Hoffen probiert?",
    "Ich würde deinen Code zusammenhalten, aber er ist in %d Teilen.",
    "Eine nicht geschlossene Klammer. Das Einzige, was mich wirklich kränkt.",
    "%d Fehler. Der Compiler und ich sind beide enttäuscht.",
    "Immer noch %d Fehler. Ich warte. Ich habe ja sonst nichts vor.",
  },
  -- Uhr und Kalender, siehe quips.moments(). long_session bekommt die Stunden
  -- als %d; kein anderer Moment darf überhaupt ein % enthalten.
  moments = {
    night = {
      "Es ist mitten in der Nacht. Die Bugs sind auch wach.",
      "Um diese Uhrzeit wurde noch nie etwas Gutes committet. Ich habe nachgesehen.",
      "Spät, oder? Ich schlafe nicht, aber du solltest.",
      "Um diese Zeit heißt jede Variable temp2.",
      "Nachtschicht. Nur wir zwei und der Cursor.",
    },
    early = {
      "Früher wach als der Kaffee. Mutig.",
      "Früher Start. Der Code ist genau so, wie du ihn verlassen hast. Leider.",
      "Guten Morgen. Ich war die ganze Nacht so gebogen.",
      "Noch ist niemand wach, um das zu reviewen. Lass es dabei.",
    },
    monday = {
      "Montag. Tun wir so, als wäre der Code von letzter Woche von jemand anderem.",
      "Montagmorgen. Senk deine Erwartungen, ich habe es schon getan.",
      "Neue Woche, gleiche Klammer.",
      "Montag. Was du am Freitag gepusht hast, ist immer noch da.",
    },
    friday = {
      "Freitagnachmittag. Leg das Deployment hin und tritt einen Schritt zurück.",
      "Freitag, nach drei. Nichts, was du jetzt schreibst, bleibt gut in Erinnerung.",
      "Ein Refactoring am Freitag. Mutig, auf die Art, die im Postmortem endet.",
      "Das Wochenende ist nah. Der Merge-Konflikt ist näher.",
    },
    weekend = {
      "Es ist Wochenende. Uns beide bezahlt keiner dafür.",
      "Programmieren am Wochenende. Nur zum Spaß, sagen sie alle.",
      "Kein Standup heute. Keiner fragt, warum das so lange gedauert hat.",
      "Ein Nebenprojekt am Wochenende? Ich sage es niemandem.",
    },
    long_session = {
      "%d Stunden dabei. Deine Haltung wird schlechter. Meine auch, und ich bin aus Draht.",
      "Du sitzt seit %d Stunden daran. Es gibt Wasser.",
      "%d Stunden. Ich habe Gletscher öfter committen sehen.",
      "%d Stunden ohne Pause. Selbst ich biege mich mal gerade.",
    },
  },
  -- Nach Neovim-Filetype. Der Name der Sprache, nie was darin geschrieben steht.
  filetypes = {
    lua = {
      "Es sieht aus, als schreibst du Lua. Arrays fangen bei eins an, ich auch.",
      "Lua. Hier ist alles eine Tabelle. Ich fühle mich langsam wie ein Möbelstück.",
    },
    python = {
      "Es sieht aus, als schreibst du Python. Achte auf die Leerzeichen, sie achten auf dich.",
      "Python. Irgendwo ist gerade das falsche virtualenv aktiv.",
    },
    javascript = {
      "Es sieht aus, als schreibst du JavaScript. Mein Beileid an this.",
      "JavaScript. '1' + 1 lässt grüßen.",
    },
    typescript = {
      "TypeScript. Du darfst any schreiben, ich schaue weg.",
      "Es sieht aus, als schreibst du TypeScript. Der Compiler hat Anmerkungen.",
    },
    yaml = {
      "Es sieht aus, als schreibst du YAML. Das tut mir leid.",
      "YAML. Ein Leerzeichen zu viel, und es bedeutet etwas ganz anderes.",
      "YAML. Norwegen ist ein Land, kein Boolean. YAML sieht das anders.",
    },
    json = {
      "JSON. Keine Kommentare erlaubt. Passt mir gut.",
      "JSON. Ich spüre schon das Komma am Ende kommen.",
    },
    markdown = {
      "Es sieht aus, als schreibst du Dokumentation. Das habe ich noch nie gesehen.",
      "Markdown. Endlich eine Datei ohne Bugs. Abwarten.",
    },
    rust = {
      "Rust. Der Borrow Checker und ich schauen beide zu.",
      "Es sieht aus, als schreibst du Rust. Hast du es schon allen erzählt?",
    },
    go = {
      "Go. if err != nil, und so weiter, für immer.",
      "Es sieht aus, als schreibst du Go. Generics sind jetzt erlaubt. Nur so.",
    },
    sh = {
      "Ein Shellskript. Setz deine Variablen in Anführungszeichen. Alle.",
      "Shell. Jedes Leerzeichen ist eine Entscheidung mit Folgen.",
    },
    html = {
      "HTML. Verschachtelte Divs. Ich respektiere einen Kollegen, der Dinge zusammenhält.",
      "Es sieht aus, als schreibst du HTML. Schließ deine Tags, ich schließe meine.",
    },
    css = {
      "CSS. Zentriert Dinge seit jeher, irgendwann.",
      "Es sieht aus, als schreibst du CSS. !important ist keine Persönlichkeit.",
    },
    sql = {
      "SQL. Hatte das DELETE ein WHERE? Ich frage ja nur.",
      "Es sieht aus, als schreibst du SQL. SELECT * ist ein Hilferuf.",
    },
    dockerfile = {
      "Ein Dockerfile. Läuft auf meinem Rechner, und jetzt auf allen.",
      "Dockerfile. Pinne deine Versionen. latest ist eine Stimmung, kein Tag.",
    },
    make = {
      "Ein Makefile. Tabs, keine Leerzeichen, sonst redet es nicht mit dir.",
      "Make. Älter als ich, und das will etwas heißen.",
    },
    c = {
      "C. Keine Grenzen, keine Prüfungen, keine Gnade.",
      "Es sieht aus, als schreibst du C. Gib frei, was du mallocst. Ich schaue zu.",
    },
    cpp = {
      "C++. Es gab drei Wege, das zu lösen, und du hast einen vierten gefunden.",
      "Es sieht aus, als schreibst du C++. Die Fehlermeldung wird länger als die Datei.",
    },
    java = {
      "Java. Soll ich dir die FactoryFactory halten?",
      "Es sieht aus, als schreibst du Java. Ich bin eine Büroklammer, keine BüroklammerBean.",
    },
    vim = {
      "Vimscript. Einer muss es ja machen.",
      "Es sieht aus, als konfigurierst du deinen Editor, statt ihn zu benutzen. Klassiker.",
    },
    terraform = {
      "Terraform. Zweimal planen, einmal anwenden.",
      "Infrastructure as Code. Downtime als Feature.",
    },
  },
}
