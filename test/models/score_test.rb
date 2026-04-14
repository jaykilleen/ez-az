require "test_helper"

class ScoreTest < ActiveSupport::TestCase
  setup do
    Score.delete_all
  end

  # Validations

  test "valid score saves" do
    score = Score.new(game: "space-dodge", name: "AZ", value: 100)
    assert score.valid?
    assert score.save
  end

  test "rejects unknown game" do
    score = Score.new(game: "pong", name: "AZ", value: 100)
    assert_not score.valid?
    assert_includes score.errors[:game], "is not included in the list"
  end

  test "rejects missing game" do
    score = Score.new(game: nil, name: "AZ", value: 100)
    assert_not score.valid?
  end

  test "rejects zero value" do
    score = Score.new(game: "space-dodge", name: "AZ", value: 0)
    assert_not score.valid?
  end

  test "rejects negative value" do
    score = Score.new(game: "space-dodge", name: "AZ", value: -5)
    assert_not score.valid?
  end

  test "rejects non-integer value" do
    score = Score.new(game: "space-dodge", name: "AZ", value: 1.5)
    assert_not score.valid?
  end

  # Name normalization

  test "uppercases name" do
    score = Score.create!(game: "space-dodge", name: "charlie", value: 100)
    assert_equal "CHARLIE", score.name
  end

  test "truncates name to 12 chars" do
    score = Score.create!(game: "space-dodge", name: "ABCDEFGHIJKLMNOP", value: 100)
    assert_equal "ABCDEFGHIJKL", score.name
    assert_equal 12, score.name.length
  end

  test "defaults blank name to game default for space-dodge" do
    score = Score.create!(game: "space-dodge", name: "", value: 100)
    assert_equal "C&C", score.name
  end

  test "defaults blank name to game default for dodgeball" do
    score = Score.create!(game: "dodgeball", name: "", value: 100)
    assert_equal "LACHIE", score.name
  end

  test "defaults blank name to game default for bloom" do
    score = Score.create!(game: "bloom", name: "  ", value: 5000)
    assert_equal "ANON", score.name
  end

  test "defaults blank name to game default for descent" do
    score = Score.create!(game: "descent", name: "", value: 60000)
    assert_equal "ANON", score.name
  end

  test "defaults blank name to game default for corrupted" do
    score = Score.create!(game: "corrupted", name: "", value: 2000)
    assert_equal "COOPER", score.name
  end

  # Sorting

  test "top_10 sorts space-dodge descending" do
    Score.create!(game: "space-dodge", name: "AAA", value: 100)
    Score.create!(game: "space-dodge", name: "BBB", value: 500)
    Score.create!(game: "space-dodge", name: "CCC", value: 300)

    values = Score.top_10("space-dodge").pluck(:value)
    assert_equal [500, 300, 100], values
  end

  test "top_10 sorts bloom ascending" do
    Score.create!(game: "bloom", name: "AAA", value: 5000)
    Score.create!(game: "bloom", name: "BBB", value: 2000)
    Score.create!(game: "bloom", name: "CCC", value: 8000)

    values = Score.top_10("bloom").pluck(:value)
    assert_equal [2000, 5000, 8000], values
  end

  test "top_10 sorts dodgeball descending" do
    Score.create!(game: "dodgeball", name: "AAA", value: 100)
    Score.create!(game: "dodgeball", name: "BBB", value: 500)
    Score.create!(game: "dodgeball", name: "CCC", value: 300)

    values = Score.top_10("dodgeball").pluck(:value)
    assert_equal [500, 300, 100], values
  end

  test "top_10 sorts descent ascending" do
    Score.create!(game: "descent", name: "AAA", value: 90000)
    Score.create!(game: "descent", name: "BBB", value: 45000)
    Score.create!(game: "descent", name: "CCC", value: 120000)

    values = Score.top_10("descent").pluck(:value)
    assert_equal [45000, 90000, 120000], values
  end

  test "top_10 sorts corrupted descending" do
    Score.create!(game: "corrupted", name: "AAA", value: 1000)
    Score.create!(game: "corrupted", name: "BBB", value: 5000)
    Score.create!(game: "corrupted", name: "CCC", value: 3000)

    values = Score.top_10("corrupted").pluck(:value)
    assert_equal [5000, 3000, 1000], values
  end

  test "top_10 limits to 10 results" do
    12.times do |i|
      Score.create!(game: "space-dodge", name: "P#{i}", value: (i + 1) * 100)
    end

    assert_equal 10, Score.top_10("space-dodge").count
  end

  test "top_10 filters by game" do
    Score.create!(game: "space-dodge", name: "AAA", value: 100)
    Score.create!(game: "bloom", name: "BBB", value: 5000)

    results = Score.top_10("space-dodge")
    assert_equal 1, results.count
    assert_equal "AAA", results.first.name
  end
end
