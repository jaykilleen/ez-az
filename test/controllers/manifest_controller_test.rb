require "test_helper"

class ManifestControllerTest < ActionDispatch::IntegrationTest
  test "manifest returns 200 with json content type" do
    get "/manifest.json"
    assert_response :success
    assert_includes response.content_type, "application/json"
  end

  test "manifest has PWA metadata" do
    get "/manifest.json"
    data = JSON.parse(response.body)
    assert_equal "EZ-AZ",       data["name"]
    assert_equal "EZ-AZ",       data["short_name"]
    assert_equal "/",           data["start_url"]
    assert_equal "fullscreen",  data["display"]
    assert_equal "#0a0a12",     data["background_color"]
    assert_equal "#00ffc8",     data["theme_color"]
  end

  test "manifest icons use fingerprinted asset paths" do
    get "/manifest.json"
    data = JSON.parse(response.body)
    assert_equal 4, data["icons"].length,
      "expected 4 icon entries (any + maskable for 192 and 512)"

    data["icons"].each do |icon|
      assert_match %r{\A/assets/icons/az-(192|512)-[0-9a-f]+\.png\z}, icon["src"],
        "icon src should be a fingerprinted asset path, got: #{icon['src']}"
      assert_includes %w[192x192 512x512], icon["sizes"]
      assert_equal "image/png", icon["type"]
      assert_includes %w[any maskable], icon["purpose"]
    end
  end

  test "manifest includes both any and maskable variants" do
    get "/manifest.json"
    data = JSON.parse(response.body)
    purposes = data["icons"].map { |i| i["purpose"] }.sort
    assert_equal %w[any any maskable maskable], purposes
  end
end
