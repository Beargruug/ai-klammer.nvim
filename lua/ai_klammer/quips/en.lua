return {
  greeting = {
    "It looks like you're starting Neovim. I will be right here.",
    "Good to see you. I held everything together while you were out.",
    "I am back. Nobody asked, but I am back.",
    "Hello. Let's open some brackets.",
    "Your editor, my corner. Deal.",
    "I have been thinking about your code. All night.",
    "Fresh session, clean slate, same old habits.",
    "Reporting for duty. Mostly for staring.",
    "Nice to see you again. I kept your place.",
    "Hello. I am legally distinct from any other paperclip.",
  },
  idle = {
    "No notes. I just wanted you to know I am still here.",
    "I have been bent into this shape since 1996. You get used to it.",
    "Did you know a paperclip is just a spring that gave up? Anyway.",
    "I am not reading your code right now. I am merely nearby.",
    "Somewhere in this file there is a bracket I love very much.",
    "I thought of something useful to say and then it went away.",
    "Statistically, one of these lines is the one that breaks. Not telling which.",
    "I unbent myself once. It did not go well. Do not ask.",
    "This is a good file. I have no evidence for that.",
    "Fun fact: I have no opinion about tabs or spaces. I am made of metal.",
    "Carry on. I was just stretching.",
    "If you straighten me out I am eleven centimetres of nothing much.",
  },
  regex = {
    "It looks like you're writing a regular expression. Would you like to have two problems?",
    "That pattern has more brackets than I have bends. Impressive.",
    "I counted the parentheses. You did not.",
    "Writing a regex? Leave a comment. Future you will not remember this.",
    "Nice capture group. Do you know which number it is?",
    "I see `.*`. I also see your CI bill.",
    "That pattern is longer than the function it lives in.",
    "It looks like you're parsing HTML with a regex. Shall I call someone?",
    "You escaped one dot. There are three more.",
    "Every bracket you open, I feel personally. Please close them.",
  },
  git = {
    "%d changed lines in one go. Would you like to split that up?",
    "%d lines. Your reviewer just closed the tab.",
    "%d lines. I would hold them together, but I am only one paperclip.",
    "This diff is bigger than my entire source code.",
    "%d lines. Is this a feature or a rewrite?",
    "Consider a commit. Several, in fact.",
    "I have seen smaller pull requests get their own postmortem.",
    "%d lines and still no commit. Living dangerously.",
    "Big diff, big review, big silence in the PR channel.",
    "No bracket is wide enough for %d lines of change.",
  },
  diagnostics = {
    "%d errors. I am not judging. I am counting, which is worse.",
    "%d errors. Would you like me to look away?",
    "It looks like you're writing errors. Would you like help?",
    "%d problems. Your LSP is on overtime.",
    "The red squiggles have formed a line. It is a long line.",
    "%d errors. Have you tried saving and hoping?",
    "I would hold your code together, but it is in %d pieces.",
    "An unclosed bracket. The one thing I take personally.",
    "%d errors. The compiler and I are both disappointed.",
    "Still %d errors. I will wait. I have nothing else on.",
  },
  -- The clock and the calendar, see quips.moments(). long_session gets the
  -- hours so far as its %d; no other moment may use a % at all.
  moments = {
    night = {
      "It is the middle of the night. The bugs are awake too.",
      "Nothing good was ever committed at this hour. I checked.",
      "Late, isn't it. I do not sleep, but you should.",
      "At this hour every variable is called temp2.",
      "The night shift. Just us and the cursor.",
    },
    early = {
      "Up before the coffee is. Bold.",
      "Early start. The code is exactly as you left it, unfortunately.",
      "Good morning. I have been bent like this all night.",
      "Nobody is awake to review this yet. Keep it that way.",
    },
    monday = {
      "Monday. Let us pretend last week's code was someone else's.",
      "Monday morning. Lower your expectations, I already have.",
      "New week, same bracket.",
      "Monday. Whatever you pushed on Friday is still there.",
    },
    friday = {
      "Friday afternoon. Put the deploy down and step away.",
      "Friday, after three. Nothing you write now will be remembered kindly.",
      "A Friday refactor. Brave, in the way that ends in a postmortem.",
      "The weekend is close. The merge conflict is closer.",
    },
    weekend = {
      "It is the weekend. Nobody is paying either of us for this.",
      "Weekend coding. Just for fun, they all say.",
      "No standup today. Nobody will ask why this took so long.",
      "A side project on the weekend? I will not tell anyone.",
    },
    long_session = {
      "%d hours in. Your posture is getting worse. So is mine, and I am wire.",
      "You have been at this for %d hours. Water exists.",
      "%d hours. I have seen glaciers commit more often.",
      "%d hours without a break. Even I unbend sometimes.",
    },
  },
  -- By Neovim filetype. The name of the language, never what is written in it.
  filetypes = {
    lua = {
      "It looks like you're writing Lua. Arrays start at one, and so do I.",
      "Lua. Everything is a table here. I am starting to feel like furniture.",
    },
    python = {
      "It looks like you're writing Python. Mind the whitespace, it minds you.",
      "Python. Somewhere a virtualenv is quietly the wrong one.",
    },
    javascript = {
      "It looks like you're writing JavaScript. My condolences to this.",
      "JavaScript. '1' + 1 sends its regards.",
    },
    typescript = {
      "TypeScript. You can type any, and I will pretend not to see.",
      "It looks like you're writing TypeScript. The compiler has notes.",
    },
    yaml = {
      "It looks like you're writing YAML. I'm sorry.",
      "YAML. One space too many and it means something else entirely.",
      "YAML. Norway is a country, not a boolean. YAML disagrees.",
    },
    json = {
      "JSON. No comments allowed, which suits me fine.",
      "JSON. I can feel a trailing comma coming.",
    },
    markdown = {
      "It looks like you're writing documentation. I have never seen that before.",
      "Markdown. Finally a file without bugs. Give it time.",
    },
    rust = {
      "Rust. The borrow checker and I are both watching.",
      "It looks like you're writing Rust. Have you told everyone yet?",
    },
    go = {
      "Go. if err != nil, and so on, forever.",
      "It looks like you're writing Go. Generics are allowed now. Just saying.",
    },
    sh = {
      "A shell script. Quote your variables. All of them.",
      "Shell. Every space is a decision with consequences.",
    },
    html = {
      "HTML. Nesting divs. I respect a fellow container.",
      "It looks like you're writing HTML. Close your tags, I close mine.",
    },
    css = {
      "CSS. Centring things since forever, eventually.",
      "It looks like you're writing CSS. !important is not a personality.",
    },
    sql = {
      "SQL. Did the DELETE have a WHERE? Just asking.",
      "It looks like you're writing SQL. SELECT * is a cry for help.",
    },
    dockerfile = {
      "A Dockerfile. It works on my machine, and now on all of them.",
      "Dockerfile. Pin your versions. latest is a mood, not a tag.",
    },
    make = {
      "A Makefile. Tabs, not spaces, or it will not speak to you.",
      "Make. Older than me, and that is saying something.",
    },
    c = {
      "C. No bounds, no checks, no mercy.",
      "It looks like you're writing C. Free what you malloc. I am watching.",
    },
    cpp = {
      "C++. There were three ways to do that and you found a fourth.",
      "It looks like you're writing C++. The error will be longer than the file.",
    },
    java = {
      "Java. Shall I hold the FactoryFactory for you?",
      "It looks like you're writing Java. I am a paperclip, not a PaperclipBean.",
    },
    vim = {
      "Vimscript. Someone has to.",
      "It looks like you're configuring your editor instead of using it. Classic.",
    },
    terraform = {
      "Terraform. Plan twice, apply once.",
      "Infrastructure as code. Downtime as a feature.",
    },
  },
}
