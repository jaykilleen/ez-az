require "test_helper"

class RoomChannelTest < ActionCable::Channel::TestCase
  tests RoomChannel

  setup do
    Room.delete_all
    @room = Room.create!
  end

  test "subscribes to the room channel with a valid code" do
    subscribe code: @room.code
    assert subscription.confirmed?
    assert_has_stream @room.channel_name
  end

  test "accepts lowercase codes" do
    subscribe code: @room.code.downcase
    assert subscription.confirmed?
  end

  test "rejects unknown codes" do
    subscribe code: "XXXX"
    assert subscription.rejected?
  end

  test "rejects expired rooms" do
    @room.update_column(:expires_at, 1.minute.ago)
    subscribe code: @room.code
    assert subscription.rejected?
  end

  test "member_joined broadcasts payload with members list" do
    membership = @room.memberships.create!(name: "AZ", slot: 1, role: :player)

    broadcasts_before = broadcasts(@room.channel_name).size
    RoomChannel.member_joined(@room, membership)
    msgs = broadcasts(@room.channel_name)
    assert_equal broadcasts_before + 1, msgs.size

    payload = JSON.parse(msgs.last)
    assert_equal "member_joined", payload["type"]
    assert_equal "AZ",  payload["member"]["name"]
    assert_equal 1,     payload["member"]["slot"]
    assert_equal 1,     payload["members"].size
  end

  test "game_starting broadcasts the game slug" do
    @room.update!(game_slug: "space-dodge")
    RoomChannel.game_starting(@room)
    payload = JSON.parse(broadcasts(@room.channel_name).last)
    assert_equal "game_starting", payload["type"]
    assert_equal "space-dodge",   payload["game_slug"]
  end
end
