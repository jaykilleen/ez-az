require "test_helper"

class TvControllerTest < ActionDispatch::IntegrationTest
  test "tv page returns 200" do
    get "/tv"
    assert_response :success
  end

  test "tv page serves html" do
    get "/tv"
    assert_includes response.content_type, "text/html"
  end

  test "tv page includes EZ-AZ branding" do
    get "/tv"
    assert_includes response.body, "EZ-AZ"
  end

  test "tv page includes all games" do
    get "/tv"
    Game.all.each do |game|
      assert_includes response.body, ERB::Util.html_escape(game[:title]),
        "tv page missing game title: #{game[:title]}"
      assert_includes response.body, ERB::Util.html_escape(game[:creators]),
        "tv page missing creators: #{game[:creators]}"
    end
  end

  test "tv page links to every game path" do
    get "/tv"
    Game.all.each do |game|
      assert_includes response.body, %(href="#{game[:path]}"),
        "tv page missing link to #{game[:path]}"
    end
  end

  test "tv page includes qr code svg" do
    get "/tv"
    assert_match(/<svg[^>]*xmlns="http:\/\/www\.w3\.org\/2000\/svg"[^>]*>/, response.body)
  end

  test "tv page includes keyboard navigation" do
    get "/tv"
    assert_includes response.body, "ArrowLeft"
    assert_includes response.body, "ArrowRight"
    assert_includes response.body, "Enter"
  end

  test "tv page uses tv layout (no app chrome)" do
    get "/tv"
    # The TV layout is minimal - no Rails CSRF tokens, no turbo etc.
    assert_not_includes response.body, "turbo-visit-control"
  end

  test "tv page has Az greeting" do
    get "/tv"
    assert_includes response.body, "Welcome"
  end

  test "tv page dark background theme" do
    get "/tv"
    assert_includes response.body, "#0a0a12"
  end
end
