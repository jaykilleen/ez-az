require "test_helper"

# The shell is the part of EZ-AZ that is not the game: store banner, title
# screen, leaderboard, pause, quit, game over. It lives in
# public/ez-az-shell.css and public/arcade-shell.js so that a new game only has
# to write the game.
#
# These tests stop that eroding. A new game must use the shell. The games that
# predate it are listed explicitly below -- that list may shrink, never grow.
class ShellAdoptionTest < ActiveSupport::TestCase
  GAMES_DIR = Rails.root.join("public", "games").freeze

  # Games written before the shared shell existed. Removing a name from this
  # list is the goal; adding one is not allowed. See docs/design-system.md.
  PRE_SHELL_GAMES = %w[
    az-cipher
    cat-vs-mouse
    corrupted
    descent
    letterbox
    marble-run
    space-dodge
  ].freeze

  # Games are either a single file (public/games/foo.html) or a folder with an
  # index (public/games/letterbox/index.html). Cover both -- a check that
  # silently skips a whole game is worse than no check.
  def game_slugs
    single = Dir[GAMES_DIR.join("*.html")].map { |p| File.basename(p, ".html") }
    folder = Dir[GAMES_DIR.join("*", "index.html")].map { |p| File.basename(File.dirname(p)) }
    (single + folder).sort
  end

  def game_path(slug)
    single = GAMES_DIR.join("#{slug}.html")
    File.exist?(single) ? single : GAMES_DIR.join(slug, "index.html")
  end

  def source(slug)
    File.read(game_path(slug))
  end

  test "every game either uses the shared shell or is a known pre-shell game" do
    missing = game_slugs.reject { |slug| source(slug).include?("ez-az-shell.css") }

    unexpected = missing - PRE_SHELL_GAMES
    assert_empty unexpected,
      "#{unexpected.inspect} do not link /ez-az-shell.css. New games must start " \
      "from docs/game-template.html so the wrapper is shared. If one of these is " \
      "genuinely a chill game with no wrapper, say so in docs/design-system.md."
  end

  test "the pre-shell list does not name games that have since been migrated" do
    stale = PRE_SHELL_GAMES.select do |slug|
      File.exist?(game_path(slug)) && source(slug).include?("ez-az-shell.css")
    end

    assert_empty stale,
      "#{stale.inspect} now use the shell -- remove them from PRE_SHELL_GAMES so " \
      "the list keeps telling the truth about what is left."
  end

  test "the pre-shell list does not name games that no longer exist" do
    gone = PRE_SHELL_GAMES - game_slugs
    assert_empty gone,
      "#{gone.inspect} are listed as pre-shell but have no file in public/games."
  end

  # The whole point of a shared sort direction is that clients stop keeping
  # their own. Catch a game reintroducing one.
  test "no game keeps its own table of which games are time-based" do
    offenders = game_slugs.select { |slug| source(slug).match?(/timeGames|isTimeGame\s*=/) }

    assert_empty offenders,
      "#{offenders.inspect} appear to keep a local map of time-based games. " \
      "Use the `sort` field returned by /api/scores (ArcadeShell does this " \
      "for you) -- local copies drift from Score::GAME_SORT."
  end

  test "the shared shell assets exist and are non-trivial" do
    css = Rails.root.join("public", "ez-az-shell.css")
    js  = Rails.root.join("public", "arcade-shell.js")

    assert File.exist?(css), "public/ez-az-shell.css is missing"
    assert File.exist?(js),  "public/arcade-shell.js is missing"
    assert_operator File.size(css), :>, 1_000
    assert_operator File.size(js),  :>, 1_000
  end

  test "arcade-shell exposes the documented wrapper API" do
    js = File.read(Rails.root.join("public", "arcade-shell.js"))

    assert_match(/window\.ArcadeShell\s*=/, js, "ArcadeShell is not exported")
    %w[banner pause leaderboard renderLeaderboard fetchScores submit qualifies format].each do |fn|
      assert_match(/^\s+#{fn}:/, js, "ArcadeShell.#{fn} is documented but not exported")
    end
  end

  test "the new-game template starts from the shell" do
    template = Rails.root.join("docs", "game-template.html")
    assert File.exist?(template), "docs/game-template.html is missing -- it is what new games copy"

    src = File.read(template)
    assert_includes src, "ez-az-shell.css", "template does not link the shell stylesheet"
    assert_includes src, "arcade-shell.js", "template does not load the shell runtime"
    assert_includes src, "ArcadeShell.banner", "template does not use the shared banner"
    assert_includes src, "ArcadeShell.pause",  "template does not use the shared pause overlay"
  end

  # The template is a starting point, not a game. If it ever lands in
  # public/games it becomes a shelf entry pointing at nothing playable.
  test "the template is not sitting in the games directory" do
    refute File.exist?(GAMES_DIR.join("game-template.html")),
      "docs/game-template.html has been copied into public/games -- everything " \
      "there is a real game on the shelf."
  end
end
