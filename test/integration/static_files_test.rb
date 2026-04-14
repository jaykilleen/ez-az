require "test_helper"

class StaticFilesTest < ActionDispatch::IntegrationTest
  # Root path

  test "root returns 200" do
    get "/"
    assert_response :success
  end

  test "root serves index html" do
    get "/"
    assert_includes response.body, "EZ-AZ"
  end

  test "root contains store content" do
    get "/"
    assert_includes response.body, "The Family Video Game Store"
    assert_includes response.body, "space-dodge.html"
  end

  # Game pages

  test "space-dodge returns 200" do
    get "/games/space-dodge.html"
    assert_response :success
  end

  test "space-dodge serves html" do
    get "/games/space-dodge.html"
    assert_includes response.content_type, "text/html"
    assert_includes response.body, "Space Dodge"
  end

  test "dodgeball returns 200" do
    get "/games/dodgeball.html"
    assert_response :success
  end

  test "dodgeball serves html" do
    get "/games/dodgeball.html"
    assert_includes response.content_type, "text/html"
    assert_includes response.body, "Dodgeball"
  end

  test "descent returns 200" do
    get "/games/descent.html"
    assert_response :success
  end

  test "descent serves html" do
    get "/games/descent.html"
    assert_includes response.content_type, "text/html"
    assert_includes response.body, "Descent"
  end

  test "corrupted returns 200" do
    get "/games/corrupted.html"
    assert_response :success
  end

  test "corrupted serves html" do
    get "/games/corrupted.html"
    assert_includes response.content_type, "text/html"
    assert_includes response.body, "Corrupted"
  end

  # Help page

  test "help returns 200" do
    get "/help.html"
    assert_response :success
  end

  test "help serves html" do
    get "/help.html"
    assert_includes response.content_type, "text/html"
    assert_includes response.body, "Submit your game"
  end

  test "help contains github link" do
    get "/help.html"
    assert_includes response.body, "github.com/jaykilleen/easy-az"
  end

  test "help contains back link" do
    get "/help.html"
    assert_includes response.body, 'href="/"'
  end

  # Navigation links on index

  test "index has game link" do
    get "/"
    assert_includes response.body, 'href="/games/space-dodge.html"'
  end

  test "index has help link" do
    get "/"
    assert_includes response.body, 'href="/help.html"'
  end

  # Store version format

  test "store version includes sha with hash" do
    get "/"
    assert_match(/store-version[^<]*#[0-9a-f]+/, response.body)
  end

  # Corrupted game box on shelf

  test "index has corrupted link" do
    get "/"
    assert_includes response.body, 'href="/games/corrupted.html"'
  end

  # 404 handling

  test "missing page returns 404" do
    get "/nope"
    assert_response :not_found
  end

  test "404 contains back link" do
    get "/nope"
    assert_includes response.body, "Back to EZ-AZ"
  end

  # Cache headers

  test "root has no-cache header" do
    get "/"
    assert_equal "no-cache", response.headers["cache-control"]
  end

  test "game has no-cache header" do
    get "/games/space-dodge.html"
    assert_equal "no-cache", response.headers["cache-control"]
  end
end
