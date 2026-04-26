require "test_helper"

class RoomTest < ActiveSupport::TestCase
  setup do
    Room.delete_all
  end

  test "creating a room assigns a 4-char code from the safe alphabet" do
    room = Room.create!
    assert_match(/\A[BCDFGHJKLMNPQRSTVWXYZ23456789]{4}\z/, room.code)
  end

  test "codes are unique across rooms" do
    codes = Array.new(10) { Room.create!.code }
    assert_equal codes, codes.uniq
  end

  test "expires_at defaults to 4 hours from now" do
    freeze = Time.utc(2026, 4, 15, 12, 0, 0)
    travel_to(freeze) do
      room = Room.create!
      assert_in_delta freeze + 4.hours, room.expires_at, 1.second
    end
  end

  test "active scope excludes expired rooms" do
    kept    = Room.create!
    expired = Room.create!
    expired.update_column(:expires_at, 1.minute.ago)

    assert_includes Room.active, kept
    refute_includes Room.active, expired
  end

  test "state defaults to lobby" do
    assert_equal "lobby", Room.create!.state
  end

  test "state enum transitions" do
    room = Room.create!
    room.playing!
    assert room.playing?
    room.finished!
    assert room.finished?
  end

  test "rejects unknown game_slug" do
    room = Room.new(code: "ABCD", expires_at: 1.hour.from_now, game_slug: "pong")
    refute room.valid?
    assert_includes room.errors[:game_slug], "is not included in the list"
  end

  test "accepts a valid game_slug" do
    room = Room.create!(game_slug: "space-dodge")
    assert_equal "space-dodge", room.game_slug
  end

  test "next_available_slot returns 1 for empty rooms" do
    assert_equal 1, Room.create!.next_available_slot
  end

  test "next_available_slot returns the lowest free slot" do
    room = Room.create!
    room.memberships.create!(name: "HOST", slot: 1, role: :host)
    room.memberships.create!(name: "TWO",  slot: 2, role: :player)
    assert_equal 3, room.next_available_slot
  end

  test "next_available_slot returns nil when full" do
    room = Room.create!
    4.times { |i| room.memberships.create!(name: "P#{i + 1}", slot: i + 1, role: :player) }
    assert_nil room.next_available_slot
  end

  test "full? reflects membership count" do
    room = Room.create!
    refute room.full?
    4.times { |i| room.memberships.create!(name: "P#{i + 1}", slot: i + 1, role: :player) }
    assert room.full?
  end

  test "touch_expiry! pushes expires_at forward" do
    room = Room.create!
    room.update_column(:expires_at, 5.minutes.from_now)
    room.touch_expiry!
    assert_operator room.expires_at, :>, 1.hour.from_now
  end

  test "host returns the host membership" do
    room = Room.create!
    host = room.memberships.create!(name: "HOST", slot: 1, role: :host)
    assert_equal host, room.host
  end

  test "players excludes the host" do
    room = Room.create!
    host = room.memberships.create!(name: "HOST", slot: 1, role: :host)
    p1   = room.memberships.create!(name: "ONE",  slot: 2, role: :player)
    refute_includes room.players, host
    assert_includes room.players, p1
  end

  test "channel_name is namespaced with the code" do
    room = Room.create!
    assert_equal "room:#{room.code}", room.channel_name
  end

  test "destroying a room also destroys its memberships" do
    room = Room.create!
    room.memberships.create!(name: "ONE", slot: 1, role: :player)
    assert_difference -> { RoomMembership.count }, -1 do
      room.destroy
    end
  end
end
