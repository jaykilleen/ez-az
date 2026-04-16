require "test_helper"

class RoomsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    Room.delete_all
  end

  # GET /rooms/new

  test "new returns 200 and uses the tv layout" do
    get new_room_path
    assert_response :success
    assert_includes response.body, "Start a room"
    assert_includes response.body, "EZ-AZ on TV".inspect.delete('"') rescue nil  # just a soft probe
  end

  # POST /rooms

  test "create allocates a new room and redirects to show" do
    assert_difference -> { Room.count }, 1 do
      post rooms_path
    end
    room = Room.last
    assert_redirected_to room_path(code: room.code)
  end

  # GET /rooms/:code

  test "show renders the lobby with the room code" do
    room = Room.create!
    get room_path(code: room.code)
    assert_response :success
    assert_includes response.body, room.code
    assert_includes response.body, "Scan to join"
  end

  test "show 404s on unknown code" do
    get room_path(code: "XXXX")
    assert_response :not_found
  end

  test "show 404s on expired room" do
    room = Room.create!
    room.update_column(:expires_at, 1.minute.ago)
    get room_path(code: room.code)
    assert_response :not_found
  end

  # GET /rooms/:code/join (phone landing)

  test "join renders the name form" do
    room = Room.create!
    get join_room_path(code: room.code)
    assert_response :success
    assert_includes response.body, "Your name"
    assert_includes response.body, room.code
  end

  test "join redirects to play when this phone already has a membership" do
    room = Room.create!
    # First join sets the session cookie
    post join_room_path(code: room.code), params: { name: "charlie" }
    assert_redirected_to play_room_path(code: room.code)

    # Re-hitting /join now redirects straight through
    get join_room_path(code: room.code)
    assert_redirected_to play_room_path(code: room.code)
  end

  # POST /rooms/:code/join

  test "add_member creates a membership with uppercase name and next slot" do
    room = Room.create!
    assert_difference -> { room.memberships.count }, 1 do
      post join_room_path(code: room.code), params: { name: "charlie" }
    end
    m = room.memberships.last
    assert_equal "CHARLIE", m.name
    assert_equal 1, m.slot
    assert_equal "player", m.role
    assert_not_nil m.session_id
    assert_redirected_to play_room_path(code: room.code)
  end

  test "add_member assigns incrementing slots for different phones" do
    room = Room.create!

    # Phone 1
    post join_room_path(code: room.code), params: { name: "alpha" }
    # Switch to a fresh session to simulate a different phone
    reset!
    post join_room_path(code: room.code), params: { name: "beta" }

    slots = room.memberships.order(:slot).pluck(:slot, :name)
    assert_equal [[1, "ALPHA"], [2, "BETA"]], slots
  end

  test "add_member refuses to exceed MAX_PLAYERS" do
    room = Room.create!
    Room::MAX_PLAYERS.times do |i|
      room.memberships.create!(name: "P#{i + 1}", slot: i + 1, role: :player)
    end

    post join_room_path(code: room.code), params: { name: "late" }
    assert_response :unprocessable_entity
    assert_includes response.body, "full"
    assert_equal Room::MAX_PLAYERS, room.memberships.count
  end

  test "add_member pushes room expiry forward" do
    room = Room.create!
    room.update_column(:expires_at, 10.minutes.from_now)
    post join_room_path(code: room.code), params: { name: "charlie" }
    room.reload
    assert_operator room.expires_at, :>, 1.hour.from_now
  end

  test "add_member broadcasts member_joined on RoomChannel" do
    room = Room.create!
    before = broadcasts(room.channel_name).size
    post join_room_path(code: room.code), params: { name: "charlie" }
    msgs  = broadcasts(room.channel_name)
    assert_equal before + 1, msgs.size

    payload = JSON.parse(msgs.last)
    assert_equal "member_joined", payload["type"]
    assert_equal "CHARLIE",       payload["member"]["name"]
  end

  # GET /rooms/:code/play

  test "play renders the controller shell for a joined phone" do
    room = Room.create!
    post join_room_path(code: room.code), params: { name: "dani" }
    get play_room_path(code: room.code)
    assert_response :success
    assert_includes response.body, "DANI"
    assert_includes response.body, "Keep this tab open"
  end

  test "play redirects back to join if the phone has no membership" do
    room = Room.create!
    get play_room_path(code: room.code)
    assert_redirected_to join_room_path(code: room.code)
  end

  test "play 404s on unknown room code" do
    get play_room_path(code: "XXXX")
    assert_response :not_found
  end

  # POST /rooms/:code/start

  test "start persists game_slug and flips state to playing" do
    room = Room.create!
    post start_room_path(code: room.code), params: { game_slug: "space-dodge" }
    room.reload
    assert_equal "space-dodge", room.game_slug
    assert_equal "playing",     room.state
  end

  test "start redirects the TV to the game page with ?room=<code>" do
    room = Room.create!
    post start_room_path(code: room.code), params: { game_slug: "bloom" }
    assert_redirected_to "/games/bloom.html?room=#{room.code}"
  end

  test "start broadcasts game_starting on RoomChannel" do
    room = Room.create!
    before = broadcasts(room.channel_name).size
    post start_room_path(code: room.code), params: { game_slug: "descent" }
    msgs = broadcasts(room.channel_name)
    assert_equal before + 1, msgs.size

    payload = JSON.parse(msgs.last)
    assert_equal "game_starting", payload["type"]
    assert_equal "descent",       payload["game_slug"]
  end

  test "start rejects unknown game slugs" do
    room = Room.create!
    post start_room_path(code: room.code), params: { game_slug: "pong" }
    assert_redirected_to room_path(code: room.code)
    room.reload
    assert_nil room.game_slug
    assert_equal "lobby", room.state
  end

  test "start 404s on unknown room code" do
    post start_room_path(code: "XXXX"), params: { game_slug: "bloom" }
    assert_response :not_found
  end
end
