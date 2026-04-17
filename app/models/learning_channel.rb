class LearningChannel
  CHANNELS = [
    {
      slug:        "learn-to-code",
      title:       "Learn to Code",
      category:    "coding",
      emoji:       "💻",
      description: "Start here. Build your first programs, then level up to real languages.",
      links: [
        { label: "Scratch",   url: "https://scratch.mit.edu",        note: "Drag and drop — make games, animations and stories" },
        { label: "Code.org",  url: "https://studio.code.org",        note: "Hour of Code and full beginner courses" },
        { label: "CS50",      url: "https://cs50.harvard.edu/x",     note: "Harvard's free intro to programming" }
      ]
    },
    {
      slug:        "game-design",
      title:       "Game Design Fundamentals",
      category:    "game-design",
      emoji:       "🎮",
      description: "Why do games feel fun? Learn to design levels, mechanics and player experiences.",
      links: [
        { label: "GDC Talks",       url: "https://www.youtube.com/@GDC",           note: "Real game dev talks from the pros" },
        { label: "Extra Credits",   url: "https://www.youtube.com/@ExtraCredits",  note: "Game design theory for humans" },
        { label: "Game Maker's Toolkit", url: "https://www.youtube.com/@GMTK",    note: "Deep dives into what makes games tick" }
      ]
    },
    {
      slug:        "storytelling",
      title:       "Storytelling for Games",
      category:    "game-design",
      emoji:       "📖",
      description: "Every great game has a story. Learn to write characters, worlds and quests.",
      links: [
        { label: "Extra Credits: Story", url: "https://www.youtube.com/playlist?list=PLB9B0CA00461BB187", note: "Narrative design for games" },
        { label: "Brandon Sanderson", url: "https://www.youtube.com/@BrandonSandersonAuthor", note: "Free uni lectures on writing" }
      ]
    },
    {
      slug:        "pixel-art",
      title:       "Art and Pixel Art",
      category:    "art",
      emoji:       "🎨",
      description: "Draw the characters and worlds in your games. No art experience needed.",
      links: [
        { label: "Pixel Pete",   url: "https://www.youtube.com/@PixelPete",        note: "Pixel art tutorials from scratch" },
        { label: "Lospec",       url: "https://lospec.com",                         note: "Free pixel art tools, palettes and tutorials" },
        { label: "Piskel",       url: "https://www.piskelapp.com",                  note: "Free online pixel art and animation editor" }
      ]
    },
    {
      slug:        "sound-design",
      title:       "Sound Design and Music",
      category:    "art",
      emoji:       "🎵",
      description: "Make bleeps, bloops and bangers. Sound brings games to life.",
      links: [
        { label: "BFXR",       url: "https://www.bfxr.net",                        note: "Make 8-bit sound effects in your browser" },
        { label: "BeepBox",    url: "https://www.beepbox.co",                      note: "Compose chiptune music online for free" },
        { label: "Chrome Music Lab", url: "https://musiclab.chromeexperiments.com", note: "Google's interactive music playground" }
      ]
    },
    {
      slug:        "math-physics",
      title:       "Maths and Physics in Games",
      category:    "science",
      emoji:       "📐",
      description: "Collision detection, gravity, vectors — the maths that powers every game.",
      links: [
        { label: "3Blue1Brown",  url: "https://www.youtube.com/@3blue1brown",      note: "Maths visualised beautifully" },
        { label: "Khan Academy", url: "https://www.khanacademy.org/math",           note: "Free maths courses at every level" },
        { label: "The Coding Train", url: "https://thecodingtrain.com",            note: "Physics sims and creative coding" }
      ]
    },
    {
      slug:        "how-ai-works",
      title:       "How AI Works",
      category:    "science",
      emoji:       "🤖",
      description: "What is AI really? How do the tools you use actually think?",
      links: [
        { label: "3B1B: Neural Nets", url: "https://www.youtube.com/playlist?list=PLZHQObOWTQDNU6R1_67000Dx_ZCJB-3pi", note: "Best visual explanation of neural networks" },
        { label: "ML for Kids",       url: "https://machinelearningforkids.co.uk", note: "Train your own AI models" },
        { label: "Google Teachable Machine", url: "https://teachablemachine.withgoogle.com", note: "Train image and sound AI in the browser" }
      ]
    },
    {
      slug:        "cryptography",
      title:       "Cryptography and Secret Codes",
      category:    "science",
      emoji:       "🔐",
      description: "From Caesar ciphers to the maths that keeps the internet safe.",
      links: [
        { label: "Art of the Problem", url: "https://www.youtube.com/@ArtOfTheProblem", note: "Beautiful explainers on crypto and information theory" },
        { label: "Khan: Cryptography", url: "https://www.khanacademy.org/computing/computer-science/cryptography", note: "Free crypto course" }
      ]
    },
    {
      slug:        "coding-history",
      title:       "Coding History",
      category:    "history",
      emoji:       "🕹️",
      description: "Ada Lovelace to the iPhone — the wild story of how computing got here.",
      links: [
        { label: "Crash Course CS",   url: "https://www.youtube.com/playlist?list=PL8dPuuaLjXtNlUrzyH5r6jN9ulIgZBpdo", note: "40 episodes from punch cards to AI" },
        { label: "Computer History Museum", url: "https://computerhistory.org", note: "Stories from the people who built computing" }
      ]
    },
    {
      slug:        "cyber-safety",
      title:       "Cyber Safety and Online Security",
      category:    "safety",
      emoji:       "🛡️",
      description: "Stay safe online. Passwords, privacy, phishing — what every kid should know.",
      links: [
        { label: "Be Internet Awesome", url: "https://beinternetawesome.withgoogle.com", note: "Google's interactive safety game for kids" },
        { label: "Cyber.org",           url: "https://cyber.org/students",               note: "Cybersecurity learning for students" }
      ]
    },
    {
      slug:        "setup-computer",
      title:       "Setting Up Your Coding Computer",
      category:    "coding",
      emoji:       "🖥️",
      description: "Install the tools, set up your editor, and get ready to build real things.",
      links: [
        { label: "VS Code",       url: "https://code.visualstudio.com",             note: "Free code editor used by millions of developers" },
        { label: "GitHub",        url: "https://github.com",                         note: "Where coders save and share their work" },
        { label: "The Odin Project", url: "https://www.theodinproject.com",         note: "Free full-stack web dev curriculum" }
      ]
    }
  ].freeze

  CATEGORIES = {
    "coding"      => { label: "Coding",       colour: "#00ffc8" },
    "game-design" => { label: "Game Design",  colour: "#ff6ec7" },
    "art"         => { label: "Art & Sound",  colour: "#ffe44d" },
    "science"     => { label: "Science",      colour: "#4af" },
    "history"     => { label: "History",      colour: "#fa0" },
    "safety"      => { label: "Safety",       colour: "#6f6" }
  }.freeze

  def self.all
    CHANNELS
  end

  def self.categories
    CATEGORIES
  end
end
