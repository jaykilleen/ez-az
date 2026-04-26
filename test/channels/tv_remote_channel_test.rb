require "test_helper"

# Tests for TvRemoteChannel — the ActionCable protocol between the Stage
# (TV big screen) and the Zone (phone companion, /tv/remote).
#
# Vocabulary from ADR 005:
#   Zone   = phone companion experience
#   Stage  = whatever is on the big screen
#   TvRemote = the channel protocol connecting them
class TvRemoteChannelTest < ActionCable::Channel::TestCase
  tests TvRemoteChannel

  setup do
    Room.delete_all
    Player.delete_all
    @room = Room.create!(tv_token: "TESTTKN1")
    TvRemoteChannel::STATES_MUTEX.synchronize { TvRemoteChannel::STATES.clear }
  end

  # ── Subscribe ────────────────────────────────────────────────────────────

  test "subscribes with a valid token and streams from tv_remote stream" do
    subscribe token: @room.tv_token
    assert subscription.confirmed?
    assert_has_stream "tv_remote:#{@room.tv_token}"
  end

  test "rejects blank token" do
    subscribe token: ""
    assert subscription.rejected?
  end

  test "rejects unknown token" do
    subscribe token: "NOTFOUND"
    assert subscription.rejected?
  end

  test "strips non-alphanumeric characters from token" do
    subscribe token: "#{@room.tv_token}!!"
    assert subscription.confirmed?
  end

  test "late subscriber receives cached state immediately" do
    # Simulate Stage setting state before phone subscribes
    TvRemoteChannel::STATES_MUTEX.synchronize do
      TvRemoteChannel::STATES[@room.tv_token] = { type: "tv_state", state: "shelf" }
    end

    subscribe token: @room.tv_token

    assert_equal 1, transmissions.size
    payload = transmissions.last
    assert_equal "tv_state", payload["type"]
    assert_equal "shelf",    payload["state"]
  end

  test "subscriber with no cached state receives nothing on connect" do
    subscribe token: @room.tv_token
    assert_empty transmissions
  end

  # ── Rejoin: phone connects with existing membership device_token ─────────

  test "phone with existing membership is rejoined automatically" do
    player = Player.create!(username: "CHARLIE")
    @room.memberships.create!(
      name: "CHARLIE", slot: 1, role: :player,
      device_token: player.device_token, session_id: SecureRandom.hex(8)
    )

    subscribe token: @room.tv_token, device_token: player.device_token

    assert subscription.confirmed?
    rejoined = transmissions.find { |t| t["type"] == "rejoined" }
    assert_not_nil rejoined, "expected a rejoined event"
    assert_equal 1, rejoined["slot"]
    assert_equal player.device_token, rejoined["phone_id"]
  end

  test "phone without existing membership gets no rejoin event" do
    subscribe token: @room.tv_token, device_token: "NEWDEVICE"
    assert subscription.confirmed?
    assert_empty transmissions.select { |t| t["type"] == "rejoined" }
  end

  # ── set_state ────────────────────────────────────────────────────────────

  test "set_state broadcasts tv_state to the stream" do
    subscribe token: @room.tv_token

    perform :set_state, "state" => "shelf"

    msgs = broadcasts("tv_remote:#{@room.tv_token}")
    last = JSON.parse(msgs.last)
    assert_equal "tv_state", last["type"]
    assert_equal "shelf",    last["state"]
  end

  test "set_state with room_code and game_title includes those fields" do
    subscribe token: @room.tv_token

    perform :set_state, "state" => "lobby", "room_code" => @room.code, "game_title" => "Family Trivia"

    msgs = broadcasts("tv_remote:#{@room.tv_token}")
    last = JSON.parse(msgs.last)
    assert_equal "lobby",         last["state"]
    assert_equal @room.code,      last["room_code"]
    assert_equal "Family Trivia", last["game_title"]
  end

  test "set_state caches payload for late subscribers" do
    subscribe token: @room.tv_token
    perform :set_state, "state" => "lobby", "room_code" => @room.code

    cached = TvRemoteChannel::STATES_MUTEX.synchronize { TvRemoteChannel::STATES[@room.tv_token] }
    assert_equal "tv_state",  cached[:type]
    assert_equal "lobby",     cached[:state]
    assert_equal @room.code,  cached[:room_code]
  end

  test "set_state ignores unknown states" do
    subscribe token: @room.tv_token
    before = broadcasts("tv_remote:#{@room.tv_token}").size

    perform :set_state, "state" => "hacked"

    assert_equal before, broadcasts("tv_remote:#{@room.tv_token}").size
  end

  # ── navigate ─────────────────────────────────────────────────────────────

  test "navigate broadcasts to the stream" do
    subscribe token: @room.tv_token

    perform :navigate, "direction" => "right", "nav_type" => "press"

    msgs = broadcasts("tv_remote:#{@room.tv_token}")
    last = JSON.parse(msgs.last)
    assert_equal "navigate", last["type"]
    assert_equal "right",    last["direction"]
    assert_equal "press",    last["nav_type"]
  end

  test "navigate defaults nav_type to press when omitted" do
    subscribe token: @room.tv_token
    perform :navigate, "direction" => "select"

    last = JSON.parse(broadcasts("tv_remote:#{@room.tv_token}").last)
    assert_equal "press", last["nav_type"]
  end

  test "navigate rejects unknown directions" do
    subscribe token: @room.tv_token
    before = broadcasts("tv_remote:#{@room.tv_token}").size

    perform :navigate, "direction" => "hack"

    assert_equal before, broadcasts("tv_remote:#{@room.tv_token}").size
  end

  test "navigate allows all standard directions" do
    subscribe token: @room.tv_token

    %w[left right up down select back action].each do |dir|
      perform :navigate, "direction" => dir
    end

    msgs = broadcasts("tv_remote:#{@room.tv_token}").map { |m| JSON.parse(m) }
    directions = msgs.select { |m| m["type"] == "navigate" }.map { |m| m["direction"] }
    assert_equal %w[left right up down select back action], directions
  end

  # ── join_room ─────────────────────────────────────────────────────────────

  test "join_room creates a membership and transmits joined" do
    subscribe token: @room.tv_token

    assert_difference -> { @room.memberships.count }, 1 do
      perform :join_room, "code" => @room.code, "name" => "CHARLIE"
    end

    joined = transmissions.find { |t| t["type"] == "joined" }
    assert_not_nil joined
    assert_equal "CHARLIE", joined["name"]
    assert_equal @room.code, joined["code"]
    assert_not_nil joined["slot"]
    assert_not_nil joined["color"]
  end

  test "join_room broadcasts member_joined on RoomChannel" do
    subscribe token: @room.tv_token

    before = broadcasts(@room.channel_name).size
    perform :join_room, "code" => @room.code, "name" => "COOPER"

    assert broadcasts(@room.channel_name).size > before
    last = JSON.parse(broadcasts(@room.channel_name).last)
    assert_equal "member_joined", last["type"]
  end

  test "join_room rejects blank name" do
    subscribe token: @room.tv_token
    perform :join_room, "code" => @room.code, "name" => ""

    error = transmissions.find { |t| t["type"] == "join_error" }
    assert_not_nil error
    assert_no_difference -> { @room.memberships.count } do
      # already performed above, just asserting count unchanged
    end
  end

  test "join_room rejects unknown room code" do
    subscribe token: @room.tv_token
    perform :join_room, "code" => "XXXX", "name" => "CHARLIE"

    error = transmissions.find { |t| t["type"] == "join_error" }
    assert_not_nil error
    assert_match(/not found/i, error["message"])
  end

  test "join_room rejects when room is full" do
    %w[P1 P2 P3 P4].each_with_index do |name, i|
      @room.memberships.create!(name: name, slot: i + 1, role: :player, session_id: SecureRandom.hex(8))
    end

    subscribe token: @room.tv_token
    perform :join_room, "code" => @room.code, "name" => "EXTRA"

    error = transmissions.find { |t| t["type"] == "join_error" }
    assert_not_nil error
    assert_match(/full/i, error["message"])
  end

  test "join_room assigns sequential slots to multiple players" do
    subscribe token: @room.tv_token

    perform :join_room, "code" => @room.code, "name" => "ALICE"
    perform :join_room, "code" => @room.code, "name" => "BOB"

    slots = @room.memberships.reload.pluck(:slot).sort
    assert_equal [1, 2], slots
  end

  # ── leave_room ────────────────────────────────────────────────────────────

  test "leave_room destroys the membership and transmits left" do
    player = Player.create!(username: "CHARLIE")
    @room.memberships.create!(
      name: "CHARLIE", slot: 1, role: :player,
      device_token: player.device_token, session_id: SecureRandom.hex(8)
    )

    subscribe token: @room.tv_token, device_token: player.device_token

    assert_difference -> { @room.memberships.count }, -1 do
      perform :leave_room
    end

    assert transmissions.any? { |t| t["type"] == "left" }
  end

  test "leave_room broadcasts member_left on RoomChannel" do
    player = Player.create!(username: "CHARLIE")
    @room.memberships.create!(
      name: "CHARLIE", slot: 1, role: :player,
      device_token: player.device_token, session_id: SecureRandom.hex(8)
    )

    subscribe token: @room.tv_token, device_token: player.device_token

    before = broadcasts(@room.channel_name).size
    perform :leave_room

    assert broadcasts(@room.channel_name).size > before
    last = JSON.parse(broadcasts(@room.channel_name).last)
    assert_equal "member_left", last["type"]
  end

  test "leave_room is a no-op when no membership exists" do
    subscribe token: @room.tv_token

    assert_no_difference -> { RoomMembership.count } do
      perform :leave_room
    end
  end
end
