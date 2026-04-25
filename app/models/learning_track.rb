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
      ]
    },
    {
      slug:        "game-design",
      title:       "Game Design",
      emoji:       "🎮",
      colour:      "#ff6ec7",
      description: "Why do games feel fun? Design theory from the people who make them.",
      videos: [
        { title: "What Makes a Good Puzzle?",               youtube_id: "zsjC6fa_YBg", note: "Game Maker's Toolkit" },
        { title: "How Celeste Teaches You Its Mechanics",   youtube_id: "lZoQ9a7oPY8", note: "Game Maker's Toolkit" },
        { title: "Why Does Celeste Feel So Good to Play?",  youtube_id: "yorTG9at90g", note: "Game Maker's Toolkit" },
      ]
    },
    {
      slug:        "coding-history",
      title:       "Coding History",
      emoji:       "🕹️",
      colour:      "#4aaeff",
      description: "From punch cards to AI — the wild story of how computing got here.",
      videos: [
        { title: "Early Computing",             youtube_id: "O5nskjLSe40", note: "Crash Course CS #1" },
        { title: "Electronic Computing",        youtube_id: "LN0Da53lKlM", note: "Crash Course CS #2" },
        { title: "Boolean Logic & Logic Gates", youtube_id: "gI-qXk7XojA", note: "Crash Course CS #3" },
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
