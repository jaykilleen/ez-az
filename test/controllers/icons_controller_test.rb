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
end
