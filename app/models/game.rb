class Game
  GAMES = [
    {
      slug: "space-dodge",
      title: "Space Dodge",
      creators: "Charlie & Cooper",
      tagline: "2-player co-op space shooter with 6 worlds and a Void King boss",
      path: "/games/space-dodge.html",
      icon: "rocket",
      tv_optimised: true
    },
    {
      slug: "dodgeball",
      title: "Dodgeball '88",
      creators: "Lachie",
      tagline: "Top-down 2v2 dodgeball tournament, best of 3 rounds",
      path: "/games/dodgeball.html",
      icon: "dodgeball",
      tv_optimised: false
    },
    {
      slug: "corrupted",
      title: "Corrupted",
      creators: "Charlie & Cooper",
      tagline: "First-person raycaster zombie fighter, 6 themed worlds",
      path: "/games/corrupted.html",
      icon: "zombie",
      tv_optimised: false
    },
    {
      slug: "descent",
      title: "Descent",
      creators: "Jaykill",
      tagline: "Maze runner with flashlight vision and 4 dinosaur heroes",
      path: "/games/descent.html",
      icon: "maze",
      tv_optimised: true
    },
    {
      slug: "cat-vs-mouse",
      title: "Cat vs Mouse",
      creators: "Lil",
      tagline: "Rope puzzle across 8 levels, hook pegs and trap the mouse",
      path: "/games/cat-vs-mouse.html",
      icon: "cat",
      tv_optimised: false
    },
    {
      slug: "bloom",
      title: "Bloom",
      creators: "Az",
      tagline: "Chill exploration, time-based scoring, no pressure",
      path: "/games/bloom.html",
      icon: "bloom",
      tv_optimised: false
    },
    {
      slug: "trivia",
      title: "Family Trivia",
      creators: "Az",
      tagline: "Scan the QR code — everyone plays on their phone. First to buzz wins!",
      path: "/games/trivia",
      icon: "trivia",
      tv_optimised: true
    }
  ].freeze

  def self.all
    GAMES
  end

  def self.for_tv
    GAMES.select { |g| g[:tv_optimised] }
  end

  def self.coming_to_tv
    GAMES.reject { |g| g[:tv_optimised] }
  end

  def self.find(slug)
    GAMES.find { |g| g[:slug] == slug }
  end
end
