require "test_helper"

class Api::ScoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    Score.delete_all
  end

  # GET /api/scores

  test "get scores requires game param" do
    get "/api/scores"
    assert_response :bad_request
    data = JSON.parse(response.body)
    assert_equal "Unknown game", data["error"]
  end

  test "get scores rejects unknown game" do
    get "/api/scores", params: { game: "pong" }
    assert_response :bad_request
  end

  test "get scores returns empty array" do
    get "/api/scores", params: { game: "space-dodge" }
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal [], data["scores"]
  end

  test "get scores space-dodge sorted desc" do
    Score.create!(game: "space-dodge", name: "AAA", value: 100)
    Score.create!(game: "space-dodge", name: "BBB", value: 500)
    Score.create!(game: "space-dodge", name: "CCC", value: 300)

    get "/api/scores", params: { game: "space-dodge" }
    data = JSON.parse(response.body)
    values = data["scores"].map { |s| s["value"] }
    assert_equal [500, 300, 100], values
  end

  test "get scores bloom sorted asc" do
    Score.create!(game: "bloom", name: "AAA", value: 5000)
    Score.create!(game: "bloom", name: "BBB", value: 2000)
    Score.create!(game: "bloom", name: "CCC", value: 8000)

    get "/api/scores", params: { game: "bloom" }
    data = JSON.parse(response.body)
    values = data["scores"].map { |s| s["value"] }
    assert_equal [2000, 5000, 8000], values
  end

  test "get scores limited to 10" do
    12.times do |i|
      Score.create!(game: "space-dodge", name: "P#{i}", value: (i + 1) * 100)
    end

    get "/api/scores", params: { game: "space-dodge" }
    data = JSON.parse(response.body)
    assert_equal 10, data["scores"].length
  end

  test "get scores filters by game" do
    Score.create!(game: "space-dodge", name: "AAA", value: 100)
    Score.create!(game: "bloom", name: "BBB", value: 5000)

    get "/api/scores", params: { game: "space-dodge" }
    data = JSON.parse(response.body)
    assert_equal 1, data["scores"].length
    assert_equal "AAA", data["scores"][0]["name"]
  end

  test "get scores has no-store cache header" do
    get "/api/scores", params: { game: "space-dodge" }
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "get scores dodgeball sorted desc" do
    Score.create!(game: "dodgeball", name: "AAA", value: 100)
    Score.create!(game: "dodgeball", name: "BBB", value: 500)
    Score.create!(game: "dodgeball", name: "CCC", value: 300)

    get "/api/scores", params: { game: "dodgeball" }
    data = JSON.parse(response.body)
    values = data["scores"].map { |s| s["value"] }
    assert_equal [500, 300, 100], values
  end

  test "get scores descent sorted asc" do
    Score.create!(game: "descent", name: "AAA", value: 90000)
    Score.create!(game: "descent", name: "BBB", value: 45000)
    Score.create!(game: "descent", name: "CCC", value: 120000)

    get "/api/scores", params: { game: "descent" }
    data = JSON.parse(response.body)
    values = data["scores"].map { |s| s["value"] }
    assert_equal [45000, 90000, 120000], values
  end

  test "get scores corrupted sorted desc" do
    Score.create!(game: "corrupted", name: "AAA", value: 1000)
    Score.create!(game: "corrupted", name: "BBB", value: 5000)
    Score.create!(game: "corrupted", name: "CCC", value: 3000)

    get "/api/scores", params: { game: "corrupted" }
    data = JSON.parse(response.body)
    values = data["scores"].map { |s| s["value"] }
    assert_equal [5000, 3000, 1000], values
  end

  # POST /api/scores

  test "post creates score" do
    post "/api/scores", params: { game: "space-dodge", name: "AZ", value: 1337 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :created
    data = JSON.parse(response.body)
    assert_equal 1, data["scores"].length
    assert_equal "AZ", data["scores"][0]["name"]
    assert_equal 1337, data["scores"][0]["value"]
  end

  test "post returns updated leaderboard" do
    Score.create!(game: "space-dodge", name: "AAA", value: 500)

    post "/api/scores", params: { game: "space-dodge", name: "BBB", value: 1000 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal 2, data["scores"].length
    assert_equal "BBB", data["scores"][0]["name"]
  end

  test "post rejects unknown game" do
    post "/api/scores", params: { game: "pong", name: "AZ", value: 100 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request
  end

  test "post rejects zero value" do
    post "/api/scores", params: { game: "space-dodge", name: "AZ", value: 0 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request
    data = JSON.parse(response.body)
    assert_equal "Value must be positive", data["error"]
  end

  test "post rejects negative value" do
    post "/api/scores", params: { game: "space-dodge", name: "AZ", value: -5 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request
  end

  test "post uppercases name" do
    post "/api/scores", params: { game: "space-dodge", name: "charlie", value: 100 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal "CHARLIE", data["scores"][0]["name"]
  end

  test "post truncates name to 12 chars" do
    post "/api/scores", params: { game: "space-dodge", name: "ABCDEFGHIJKLMNOP", value: 100 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal 12, data["scores"][0]["name"].length
    assert_equal "ABCDEFGHIJKL", data["scores"][0]["name"]
  end

  test "post defaults name space-dodge" do
    post "/api/scores", params: { game: "space-dodge", name: "", value: 100 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal "C&C", data["scores"][0]["name"]
  end

  test "post defaults name dodgeball" do
    post "/api/scores", params: { game: "dodgeball", name: "", value: 100 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal "LACHIE", data["scores"][0]["name"]
  end

  test "post defaults name descent" do
    post "/api/scores", params: { game: "descent", name: "", value: 60000 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal "ANON", data["scores"][0]["name"]
  end

  test "post defaults name bloom" do
    post "/api/scores", params: { game: "bloom", name: "  ", value: 5000 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal "ANON", data["scores"][0]["name"]
  end

  test "post defaults name corrupted" do
    post "/api/scores", params: { game: "corrupted", name: "", value: 2000 }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    data = JSON.parse(response.body)
    assert_equal "COOPER", data["scores"][0]["name"]
  end
end
