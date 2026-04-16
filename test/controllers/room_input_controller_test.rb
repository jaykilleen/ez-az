require "test_helper"

class RoomInputControllerTest < ActionDispatch::IntegrationTest
  test "GET /room-input.js returns JS content-type" do
    get "/room-input.js"
    assert_response :success
    assert_includes response.content_type, "javascript"
  end

  test "response bakes in the fingerprinted actioncable asset URL" do
    get "/room-input.js"
    assert_match %r{/assets/actioncable\.esm-[0-9a-f]+\.js}, response.body
  end

  test "response contains the per-game keymaps" do
    get "/room-input.js"
    %w[space-dodge dodgeball bloom cat-vs-mouse descent corrupted].each do |slug|
      assert_includes response.body, slug, "missing keymap for #{slug}"
    end
  end

  test "response subscribes to ControllerChannel" do
    get "/room-input.js"
    assert_includes response.body, "ControllerChannel"
    assert_includes response.body, "handle"
    assert_includes response.body, "KeyboardEvent"
  end

  test "response aborts early when no ?room= param is present" do
    get "/room-input.js"
    assert_includes response.body, 'params.get("room")'
    assert_includes response.body, "if (!code) return"
  end

  test "no-cache so updates ship immediately" do
    get "/room-input.js"
    assert_equal "no-cache", response.headers["Cache-Control"]
  end
end
