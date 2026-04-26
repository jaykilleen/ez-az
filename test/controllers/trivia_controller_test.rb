require "test_helper"

# Tests for TriviaController — the HTTP layer for Family Trivia.
#
# Key invariants after ADR 005:
#  - New trivia rooms get a tv_token so the Zone can connect via TvRemoteChannel
#  - The QR code in the lobby points to /tv/remote (Zone), not the old rooms/join
class TriviaControllerTest < ActionDispatch::IntegrationTest
  setup do
    Room.delete_all
    TvRemoteChannel::STATES_MUTEX.synchronize { TvRemoteChannel::STATES.clear }
  end

  # ── GET /games/trivia (new) ───────────────────────────────────────────────

  test "GET /games/trivia creates a room with game_slug trivia" do
    assert_difference -> { Room.count }, 1 do
      get new_trivia_path
    end
    assert_equal "trivia", Room.last.game_slug
  end

  test "GET /games/trivia gives the room a tv_token" do
    get new_trivia_path
    assert_not_nil Room.last.tv_token
    assert_match /\A[A-Z0-9]{8}\z/, Room.last.tv_token
  end

  test "GET /games/trivia redirects to the show page" do
    get new_trivia_path
    assert_redirected_to trivia_path(Room.last.code)
  end

  # ── GET /games/trivia/:code (show) ───────────────────────────────────────

  test "show renders the trivia lobby" do
    room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    get trivia_path(room.code)
    assert_response :success
    assert_includes response.body, "Family Trivia"
    assert_includes response.body, room.code
  end

  test "show uses TvRemoteChannel not legacy rooms join" do
    room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    get trivia_path(room.code)

    assert_includes response.body, "TvRemoteChannel"
    assert_not_includes response.body, "/rooms/#{room.code}/join"
  end

  test "show QR code includes the room tv_token" do
    room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    get trivia_path(room.code)
    assert_includes response.body, room.tv_token
  end

  test "show embeds the tv_token as a JS variable for TvRemoteChannel" do
    room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    get trivia_path(room.code)
    assert_includes response.body, room.tv_token.inspect
  end

  test "show generates a tv_token for legacy rooms that lack one" do
    room = Room.create!(game_slug: "trivia")
    assert_nil room.tv_token

    get trivia_path(room.code)
    assert_response :success
    assert_not_nil room.reload.tv_token
  end

  test "show redirects to new for unknown code" do
    get trivia_path("XXXX")
    assert_redirected_to new_trivia_path
  end

  test "show redirects to new for expired room" do
    room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    room.update_column(:expires_at, 1.minute.ago)
    get trivia_path(room.code)
    assert_redirected_to new_trivia_path
  end

  test "show renders waiting players from existing memberships" do
    room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    room.memberships.create!(name: "ALICE", slot: 1, role: :player, session_id: SecureRandom.hex(8))
    get trivia_path(room.code)
    assert_includes response.body, "ALICE"
  end
end
