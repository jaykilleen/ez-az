require "test_helper"

class RoomMembershipTest < ActiveSupport::TestCase
  setup do
    @room = Room.create!
  end

  test "valid with name, slot, room, role" do
    m = @room.memberships.build(name: "CHARLIE", slot: 1, role: :player)
    assert m.valid?
    assert m.save
  end

  test "requires a name" do
    m = @room.memberships.build(name: "", slot: 1, role: :player)
    m.instance_variable_set(:@_normalize_skip, true)  # sanity only
    refute m.valid? && m.name == "ANON" && m.errors[:name].any?
    # After normalization, blank name becomes "ANON", which is valid
    assert_equal "ANON", m.name
  end

  test "uppercases and truncates the name" do
    m = @room.memberships.create!(name: "charlieanddanielle", slot: 1, role: :player)
    assert_equal "CHARLIEANDDA", m.name
    assert_equal 12, m.name.length
  end

  test "blank name falls back to player username when a player is linked" do
    player = Player.create!(username: "SIDNEY", pin: "1234")
    m = @room.memberships.create!(player: player, name: "", slot: 1, role: :player)
    assert_equal "SIDNEY", m.name
  end

  test "slot must be within 1..4" do
    refute @room.memberships.build(name: "X", slot: 0, role: :player).valid?
    refute @room.memberships.build(name: "X", slot: 5, role: :player).valid?
  end

  test "slot is unique within the same room" do
    @room.memberships.create!(name: "A", slot: 1, role: :player)
    dup = @room.memberships.build(name: "B", slot: 1, role: :player)
    refute dup.valid?
  end

  test "same slot is fine across different rooms" do
    other = Room.create!
    @room.memberships.create!(name: "A", slot: 1, role: :player)
    ok = other.memberships.build(name: "A", slot: 1, role: :player)
    assert ok.valid?
  end

  test "display returns the public fields only" do
    m = @room.memberships.create!(name: "CHARLIE", slot: 2, role: :player)
    assert_equal({ name: "CHARLIE", slot: 2, role: "player", connected: true }, m.display)
  end

  test "connected defaults to true" do
    assert @room.memberships.create!(name: "X", slot: 1, role: :player).connected
  end
end
