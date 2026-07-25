require "test_helper"

class IconsControllerTest < ActionDispatch::IntegrationTest
  test "legacy /icons/az-192.png redirects to fingerprinted asset" do
    get "/icons/az-192.png"
    assert_response :moved_permanently
    assert_match %r{\A(http://www\.example\.com)?/assets/icons/az-192-[0-9a-f]+\.png\z},
                 response.headers["Location"]
  end

  test "legacy /icons/az-512.png redirects to fingerprinted asset" do
    get "/icons/az-512.png"
    assert_response :moved_permanently
    assert_match %r{\A(http://www\.example\.com)?/assets/icons/az-512-[0-9a-f]+\.png\z},
                 response.headers["Location"]
  end

  test "unknown icon filename returns 404" do
    get "/icons/hacked.png"
    assert_response :not_found
  end

  test "following the redirect lands on an actual PNG" do
    get "/icons/az-192.png"
    follow_redirect!
    assert_response :success
    assert_equal "image/png", response.content_type
  end

  test "/favicon.ico resolves instead of 404ing" do
    get "/favicon.ico"
    assert_response :moved_permanently
    follow_redirect!
    assert_response :success
    assert_equal "image/png", response.content_type
  end

  # Five templates shipped pointing at /icons/icon-192.png, a filename that has
  # never existed -- so every page built on them logged a 404 on load. Catch
  # the whole class rather than the one instance: any icon href a view emits
  # has to actually resolve.
  test "every icon link in a view template points at something real" do
    links = Dir[Rails.root.join("app/views/**/*.erb")].flat_map do |path|
      File.readlines(path).grep(/rel="(?:icon|apple-touch-icon)"/).filter_map do |line|
        # href values may be a literal path or an ERB asset_path call, and the
        # ERB form contains its own quotes -- so check for it first.
        if (asset = line[/asset_path\(["']([^"']+)["']\)/, 1])
          [ :asset, asset, path ]
        elsif (href = line[/href="([^"]+)"/, 1])
          [ :path, href, path ]
        end
      end
    end.uniq { |kind, value, _| [ kind, value ] }

    assert links.any?, "expected at least one icon link across the view templates"

    links.each do |kind, value, source|
      where = Pathname(source).relative_path_from(Rails.root)
      if kind == :asset
        assert Rails.application.assets.load_path.find(value),
          "#{where} references asset #{value}, which is not in the asset load path"
      else
        get value
        assert_includes [ 200, 301, 302 ], response.status,
          "#{where} references icon #{value}, which does not resolve (got #{response.status})"
      end
    end
  end
end
