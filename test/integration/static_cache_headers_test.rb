require "test_helper"

# Game HTML is served no-cache so a deploy is visible immediately. The shared
# runtime those games depend on used to be cached for an hour, which let a
# freshly deployed game call an ArcadeShell option that the browser's older
# copy did not understand -- the option was silently ignored rather than
# erroring, which is the worst kind of failure. See BL-017.
class StaticCacheHeadersTest < ActionDispatch::IntegrationTest
  def cache_control_for(path)
    get path
    assert_response :success, "#{path} did not serve"
    response.headers["cache-control"]
  end

  test "game HTML is never cached" do
    assert_equal "no-cache", cache_control_for("/games/magnet-lab.html")
  end

  test "the shared shell stylesheet is never cached" do
    assert_equal "no-cache", cache_control_for("/ez-az-shell.css")
  end

  test "the shared arcade runtime is never cached" do
    assert_equal "no-cache", cache_control_for("/arcade-shell.js")
  end

  test "every always-fresh path exists and is served no-cache" do
    StaticCacheHeaders::ALWAYS_FRESH.each do |path|
      assert File.exist?(Rails.root.join("public", path.delete_prefix("/"))),
        "#{path} is listed as always-fresh but no such file exists in public/"
      assert_equal "no-cache", cache_control_for(path),
        "#{path} should be served no-cache"
    end
  end

  # Everything else still gets a long cache -- cover art and audio are large
  # and do not have to move in lockstep with a deploy.
  test "ordinary static assets are still cached" do
    assert_equal "public, max-age=3600", cache_control_for("/game-covers.js")
  end

  # If a game starts depending on a shared file, that file has to be in the
  # list or it can go stale against the HTML that uses it.
  test "shared scripts that games load are all marked always-fresh" do
    shared = Dir[Rails.root.join("public", "*.js")].map { |p| "/#{File.basename(p)}" }

    used_by_games = shared.select do |script|
      Dir[Rails.root.join("public", "games", "**", "*.html")].any? do |game|
        File.read(game).include?("src=\"#{script}\"")
      end
    end

    # Deliberately allowed to stay cached: these are large, self-contained and
    # not part of the wrapper contract.
    permitted_stale = %w[/game-covers.js /controls.js /game-viewport.js /error-reporter.js /tv-music.js /tv-engine.js /dev-bar.js /sw.js]

    missing = used_by_games - StaticCacheHeaders::ALWAYS_FRESH - permitted_stale
    assert_empty missing,
      "#{missing.inspect} are loaded by games but are neither always-fresh nor " \
      "explicitly allowed to be cached. A shared file that games depend on can " \
      "go an hour stale against the HTML that uses it."
  end
end
