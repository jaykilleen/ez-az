require "test_helper"

class CodeControllerTest < ActionDispatch::IntegrationTest
  test "GET /code returns 200 and lists curated files" do
    get "/code"
    assert_response :success
    assert_includes response.body, "Under the hood"
    assert_includes response.body, "Space Dodge"
    assert_includes response.body, "Score model"
    assert_includes response.body, "Touch controls"
  end

  test "GET /code groups files by category" do
    get "/code"
    %w[Games Store\ frontend Rails\ backend].each do |cat|
      assert_includes response.body, cat, "missing category: #{cat}"
    end
  end

  test "GET /code/view serves a whitelisted file" do
    get "/code/view", params: { path: "config/routes.rb" }
    assert_response :success
    assert_includes response.body, "routes.rb"
    assert_includes response.body, "Rails.application.routes.draw"
    assert_includes response.body, "View on GitHub"
  end

  test "GET /code/view serves a game file" do
    get "/code/view", params: { path: "public/games/bloom.html" }
    assert_response :success
    assert_includes response.body, "Bloom"
    assert_match(/language-markup/, response.body)
  end

  test "GET /code/view 404s on non-whitelisted paths" do
    get "/code/view", params: { path: "config/database.yml" }
    assert_response :not_found
  end

  test "GET /code/view 404s on path traversal attempts" do
    get "/code/view", params: { path: "../../etc/passwd" }
    assert_response :not_found
  end

  test "GET /code/view 404s when no path is provided" do
    get "/code/view"
    assert_response :not_found
  end

  test "every curated entry maps to a real file on disk" do
    CodeController::CURATED.each do |entry|
      assert File.exist?(Rails.root.join(entry[:path])),
        "curated file missing from disk: #{entry[:path]}"
    end
  end

  test "every curated entry has required fields" do
    CodeController::CURATED.each do |entry|
      assert entry[:path].present?,     "missing :path in #{entry.inspect}"
      assert entry[:label].present?,    "missing :label in #{entry.inspect}"
      assert entry[:blurb].present?,    "missing :blurb in #{entry.inspect}"
      assert entry[:category].present?, "missing :category in #{entry.inspect}"
    end
  end

  test "source code is HTML-escaped in the viewer" do
    get "/code/view", params: { path: "public/games/bloom.html" }
    # HTML tags in the source must be escaped so they render as visible
    # code, not as live HTML elements.
    refute_match(/<canvas id="game">/, response.body)
    assert_match(/&lt;canvas/, response.body)
  end
end
