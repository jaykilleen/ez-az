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

  test "find returns game by slug" do
    assert_equal "Space Dodge", Game.find("space-dodge")[:title]
  end

  test "find returns nil for unknown slug" do
    assert_nil Game.find("pong")
  end

  test "every game path points to an existing file in public" do
    Game.all.each do |game|
      file = Rails.root.join("public", game[:path].sub(%r{^/}, ""))
      assert File.exist?(file), "missing file for #{game[:slug]}: #{file}"
    end
  end
end
