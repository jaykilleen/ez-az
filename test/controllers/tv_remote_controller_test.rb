require "test_helper"

# Tests for TvRemoteController — serves the Zone HTML at /tv/remote.
#
# Two entry paths:
#   /tv/remote?token=X        — via QR badge scan from Shelf or Party Stage
#   /tv/remote?code=XXXX      — via manual code entry on the scan page
class TvRemoteControllerTest < ActionDispatch::IntegrationTest
  setup do
    Room.delete_all
    @room = Room.create!(tv_token: "TESTTKN1")
  end

  # ── Token path (/tv/remote?token=X) ──────────────────────────────────────

  test "renders Zone with valid token" do
    get tv_remote_path(token: @room.tv_token)
    assert_response :success
  end

  test "renders Zone content for the token" do
    get tv_remote_path(token: @room.tv_token)
    assert_includes response.body, "EZ-AZ"
    assert_includes response.body, @room.tv_token.inspect
  end

  test "response is not cached" do
    get tv_remote_path(token: @room.tv_token)
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "redirects to /tv when token is blank" do
    get tv_remote_path(token: "")
    assert_redirected_to tv_path
  end

  test "redirects to /tv when token is unknown" do
    get tv_remote_path(token: "NOTFOUND")
    assert_redirected_to tv_path
  end

  test "strips non-alphanumeric characters from token" do
    get tv_remote_path(token: "#{@room.tv_token}!!")
    assert_response :success
  end

  # ── Code path (/tv/remote?code=XXXX) ─────────────────────────────────────

  test "renders Zone when entering via room code" do
    get tv_remote_path(code: @room.code)
    assert_response :success
  end

  test "embeds the token from room lookup when entering by code" do
    get tv_remote_path(code: @room.code)
    assert_includes response.body, @room.tv_token.inspect
  end

  test "redirects home for unknown code" do
    get tv_remote_path(code: "XXXX")
    assert_redirected_to "/"
  end

  test "code path accepts lowercase input" do
    get tv_remote_path(code: @room.code.downcase)
    assert_response :success
  end

  test "room with no tv_token is unserviceable via code path" do
    room = Room.create!
    assert_nil room.tv_token
    get tv_remote_path(code: room.code)
    # Controller sets @token = room.tv_token which is nil — redirects to /tv
    assert_redirected_to "/"
  end

  # ── Cache busting ─────────────────────────────────────────────────────────

  test "code path response is not cached" do
    get tv_remote_path(code: @room.code)
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
