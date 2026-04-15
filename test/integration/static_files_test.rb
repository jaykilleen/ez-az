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

  test "index fetches version from api" do
    get "/"
    assert_includes response.body, "/api/version"
    assert_includes response.body, %(id="storeVersion")
  end

  # Closed page

  test "closed page returns 200" do
    get "/closed.html"
    assert_response :success
  end

  test "closed page serves html" do
    get "/closed.html"
    assert_includes response.content_type, "text/html"
    assert_includes response.body, "CLOSED"
  end

  test "closed page includes store version element" do
    get "/closed.html"
    assert_includes response.body, %(id="storeVersion")
    assert_includes response.body, "store-version"
  end

  test "closed page fetches version from api" do
    get "/closed.html"
    assert_includes response.body, "/api/version"
  end

  test "closed page references shared opening-hours script" do
    get "/closed.html"
    assert_includes response.body, %(src="/opening-hours.js")
  end

  test "closed page has school-holiday UI hooks" do
    get "/closed.html"
    assert_includes response.body, %(id="holidayNote")
    assert_includes response.body, %(id="weekdayHours")
  end

  # Shared opening-hours script

  test "opening-hours js is served" do
    get "/opening-hours.js"
    assert_response :success
    assert_match(/javascript/, response.content_type)
  end

  test "opening-hours js declares EzAzHours api" do
    get "/opening-hours.js"
    assert_includes response.body, "window.EzAzHours"
    assert_includes response.body, "isOpen"
    assert_includes response.body, "nextOpening"
    assert_includes response.body, "onHoliday"
  end

  test "opening-hours js redirects from closed page to root when store is open" do
    get "/opening-hours.js"
    assert_includes response.body, "/closed.html",
      "should mention the closed page path"
    assert_match(/onClosedPage.*storeOpen|storeOpen.*onClosedPage/m, response.body,
      "should check both storeOpen and onClosedPage to decide where to redirect")
    assert_includes response.body, 'window.location.replace("/")',
      "should redirect home when the store reopens while on the closed page"
  end

  test "service worker does not pre-cache HTML shell files" do
    get "/sw.js"
    assert_response :success
    # HTML files must go through network-first-no-fallback so the holiday
    # redirect and opening-hours.js are never served stale after a deploy.
    refute_match(/games\/.*\.html/, response.body,
      "sw.js SHELL should not pre-cache game HTML — it needs to be always-fresh")
    refute_match(/'\/closed\.html'/, response.body,
      "sw.js SHELL should not pre-cache closed.html")
  end

  test "service worker treats opening-hours script as network-only" do
    get "/sw.js"
    assert_includes response.body, "opening-hours.js"
    assert_match(/network-only|isOpeningHoursScript|isHtmlNavigation/i, response.body)
  end

  test "opening-hours js contains a holidays array" do
    get "/opening-hours.js"
    assert_includes response.body, "HOLIDAYS"
    assert_match(/from:\s*"\d{4}-\d{2}-\d{2}"/, response.body)
    assert_match(/to:\s*"\d{4}-\d{2}-\d{2}"/, response.body)
  end

  test "index references shared opening-hours script" do
    get "/"
    assert_includes response.body, %(src="/opening-hours.js")
    # And no longer has an inline duplicate
    refute_match(/day >= 1 && day <= 5 && hm >= 960/, response.body)
  end

  test "every game page references shared opening-hours script" do
    %w[space-dodge bloom cat-vs-mouse dodgeball descent corrupted].each do |slug|
      get "/games/#{slug}.html"
      assert_response :success
      assert_includes response.body, %(src="/opening-hours.js"),
        "#{slug} is missing the shared opening-hours script"
      refute_match(/day >= 1 && day <= 5 && hm >= 960/, response.body,
        "#{slug} still contains the inline opening-hours copy")
    end
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
