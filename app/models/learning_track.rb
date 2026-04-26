class LearningTrack
  # Tracks are curated via conversation — add youtube_id (the part after ?v= in the YouTube URL).
  TRACKS = [
    {
      slug:        "how-ai-works",
      title:       "How AI Works",
      emoji:       "🤖",
      colour:      "#00ffc8",
      description: "What's actually happening inside AI? From neural nets to the tools you use every day.",
      videos: [
        { title: "But what is a neural network?",               youtube_id: "aircAruvnKk", note: "3Blue1Brown" },
        { title: "Gradient descent: how neural networks learn", youtube_id: "IHZwWFHWa-w", note: "3Blue1Brown" },
        { title: "What is backpropagation really doing?",       youtube_id: "Ilg3gGewQ5U", note: "3Blue1Brown" },
        { title: "Backpropagation calculus",                    youtube_id: "tIeHLnjs5U8", note: "3Blue1Brown" },
        { title: "Large Language Models explained briefly",     youtube_id: "LPZh9BOjkQs", note: "3Blue1Brown" },
        { title: "How might LLMs store facts",                  youtube_id: "9-Jl0dxWQs8", note: "3Blue1Brown" },
        { title: "Attention in transformers, visually",         youtube_id: "eMlx5fFNoYc", note: "3Blue1Brown" },
      ]
    },
    {
      slug:        "maths-for-games",
      title:       "Maths for Games",
      emoji:       "📐",
      colour:      "#ffe44d",
      description: "Vectors, coordinates and the maths that makes games move.",
      videos: [
        { title: "Vectors, what even are they?",         youtube_id: "fNk_zzaMoSs", note: "3Blue1Brown" },
        { title: "Linear transformations and matrices",  youtube_id: "kYB8IZa5AuE", note: "3Blue1Brown" },
        { title: "Matrix multiplication as composition", youtube_id: "XkY2DOUCWMU", note: "3Blue1Brown" },
        { title: "The determinant",                      youtube_id: "Ip3X9LOh2dk", note: "3Blue1Brown" },
        { title: "Dot products and duality",             youtube_id: "LyGKycYT2v0", note: "3Blue1Brown" },
        { title: "Cross products",                       youtube_id: "eu6i7WJeinw", note: "3Blue1Brown" },
        { title: "Essence of calculus",                  youtube_id: "WUvTyaaNkzM", note: "3Blue1Brown" },
        { title: "The paradox of the derivative",        youtube_id: "9vKqVkMQHKk", note: "3Blue1Brown" },
      ]
    },
    {
      slug:        "game-design",
      title:       "Game Design",
      emoji:       "🎮",
      colour:      "#ff6ec7",
      description: "Why do games feel fun? Design theory from the people who make them.",
      videos: [
        { title: "What Makes a Good Puzzle?",                  youtube_id: "zsjC6fa_YBg", note: "Game Maker's Toolkit" },
        { title: "How Celeste Teaches You Its Mechanics",      youtube_id: "lZoQ9a7oPY8", note: "Game Maker's Toolkit" },
        { title: "Why Does Celeste Feel So Good to Play?",     youtube_id: "yorTG9at90g", note: "Game Maker's Toolkit" },
        { title: "How Games Use Feedback Loops",               youtube_id: "H4kbJObhcHo", note: "Game Maker's Toolkit" },
        { title: "What Makes a Satisfying Ending?",           youtube_id: "fce_HKGMcKI", note: "Game Maker's Toolkit" },
        { title: "The Theory of Fun",                          youtube_id: "6cBN8AjJt4E", note: "GDC" },
        { title: "Juice it or Lose it",                        youtube_id: "Fy0aCDmgnxg", note: "GDC" },
        { title: "How to make your game feel great",           youtube_id: "AJdEqssNZ-U", note: "GDC" },
      ]
    },
    {
      slug:        "coding-history",
      title:       "Coding History",
      emoji:       "🕹️",
      colour:      "#4aaeff",
      description: "From punch cards to AI — the wild story of how computing got here.",
      videos: [
        { title: "Early Computing",                  youtube_id: "O5nskjLSe40", note: "Crash Course CS #1" },
        { title: "Electronic Computing",             youtube_id: "LN0Da53lKlM", note: "Crash Course CS #2" },
        { title: "Boolean Logic & Logic Gates",      youtube_id: "gI-qXk7XojA", note: "Crash Course CS #3" },
        { title: "Representing Numbers & Letters",   youtube_id: "1GSjbWt0c9M", note: "Crash Course CS #4" },
        { title: "How Computers Calculate — the ALU",youtube_id: "1I5ZMmrOfnA", note: "Crash Course CS #5" },
        { title: "Registers and RAM",                youtube_id: "fpnE6UAfbtU", note: "Crash Course CS #6" },
        { title: "The Central Processing Unit",      youtube_id: "FZGugFqdr60", note: "Crash Course CS #7" },
        { title: "Instructions & Programs",          youtube_id: "zltgXvg6r3k", note: "Crash Course CS #8" },
        { title: "Advanced CPU Designs",             youtube_id: "sK-49uz3lGg", note: "Crash Course CS #9" },
        { title: "Early Programming",                youtube_id: "nwDq4adJwzM", note: "Crash Course CS #10" },
      ]
    },
    {
      slug:        "how-things-work",
      title:       "How Things Work",
      emoji:       "⚡",
      colour:      "#ff8c42",
      description: "The science and engineering behind everyday technology.",
      videos: [
        { title: "How does your phone know where you are?",    youtube_id: "aY8pLSuQeuw", note: "Kurzgesagt" },
        { title: "How does WiFi work?",                        youtube_id: "hePLDVbULZc", note: "Kurzgesagt" },
        { title: "How does the Internet work?",                youtube_id: "x3c1ih2NJEg", note: "Kurzgesagt" },
        { title: "The Quantum World",                          youtube_id: "JhHMJCUmq28", note: "Kurzgesagt" },
        { title: "What is electricity?",                       youtube_id: "ru032Mfsfig", note: "Crash Course Physics" },
        { title: "Electric Current",                           youtube_id: "mvDcCommonvE", note: "Crash Course Physics" },
      ]
    },
    {
      slug:        "space",
      title:       "Space",
      emoji:       "🚀",
      colour:      "#a78bfa",
      description: "Black holes, rockets, and the size of everything.",
      videos: [
        { title: "Black Holes Explained",                          youtube_id: "e-P5IFTqB98", note: "Kurzgesagt" },
        { title: "The Size of the Universe",                       youtube_id: "GoW8Tf7hTGA", note: "Kurzgesagt" },
        { title: "How to Understand the Image of a Black Hole",    youtube_id: "zUyH3XhpLTo", note: "Veritasium" },
        { title: "Why the Universe is Way Bigger Than You Think",  youtube_id: "Iy7NzjCmUf0", note: "Kurzgesagt" },
        { title: "How We're Going Back to the Moon",               youtube_id: "JFBGR0l2VoI", note: "Veritasium" },
        { title: "What Does Space Smell Like?",                    youtube_id: "8B9KMgBFBpM", note: "Veritasium" },
      ]
    },
  ].freeze

  def self.all
    TRACKS
  end

  def self.find(slug)
    TRACKS.find { |t| t[:slug] == slug }
  end
end
