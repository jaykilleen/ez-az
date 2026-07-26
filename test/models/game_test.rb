require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "all returns a frozen list of games" do
    assert Game.all.frozen?
    assert_operator Game.all.length, :>=, 6
  end

  test "every game has required fields" do
    Game.all.each do |game|
      assert game[:slug].present?, "game missing slug"
      assert game[:title].present?, "game #{game[:slug]} missing title"
      assert game[:creators].present?, "game #{game[:slug]} missing creators"
      assert game[:tagline].present?, "game #{game[:slug]} missing tagline"
      assert game[:path].present?, "game #{game[:slug]} missing path"
      assert game[:icon].present?, "game #{game[:slug]} missing icon"
    end
  end

  test "every game slug is registered in Score::GAME_SORT" do
    Game.all.each do |game|
      assert Score::GAME_SORT.key?(game[:slug]),
        "game slug #{game[:slug]} not registered in Score::GAME_SORT"
    end
  end

  # The reverse direction, which is how az-cipher went missing: it had a
  # leaderboard and a shelf card but no Game entry, so it was absent from
  # Game.all -- and therefore from the bug reporter's game dropdown, meaning
  # kids had no way to report a bug against it.
  test "every scored game is registered in Game::GAMES" do
    registered = Game.all.map { |g| g[:slug] }
    Score::GAME_SORT.each_key do |slug|
      assert_includes registered, slug,
        "#{slug} has a leaderboard in Score::GAME_SORT but no entry in Game::GAMES, " \
        "so it will not appear in Game.all (bug reporter, rooms list, TV list)"
    end
  end

  # CLAUDE.md lists the shelf as one of the registration points a new game has
  # to hit. Compare by path rather than slug: only some cards carry a
  # data-game High Scores span, but every card links to the game.
  test "the shelf and Game::GAMES list the same games" do
    shelf = File.read(Rails.root.join("public", "index.html"))
             .scan(%r{href="(/games/[a-z0-9./-]+)"}).flatten.uniq.sort
    registered = Game.all.map { |g| g[:path] }.sort

    assert shelf.any?, "found no game links on the shelf -- has the markup changed?"
    assert_equal registered, shelf,
      "the shelf in public/index.html and Game::GAMES have drifted. " \
      "Only on the shelf: #{(shelf - registered).inspect}. " \
      "Only in Game::GAMES: #{(registered - shelf).inspect}."
  end

  test "find returns game by slug" do
    assert_equal "Space Dodge", Game.find("space-dodge")[:title]
  end

  test "find returns nil for unknown slug" do
    assert_nil Game.find("pong")
  end

  test "every static game path points to an existing file in public" do
    Game.all.each do |game|
      next unless game[:path].end_with?(".html")
      file = Rails.root.join("public", game[:path].sub(%r{^/}, ""))
      assert File.exist?(file), "missing file for #{game[:slug]}: #{file}"
    end
  end
end
