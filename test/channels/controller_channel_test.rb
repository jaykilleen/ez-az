require "test_helper"

class ControllerChannelTest < ActionCable::Channel::TestCase
  tests ControllerChannel

  setup do
    Room.delete_all
    @room       = Room.create!
    @membership = @room.memberships.create!(name: "CHARLIE", slot: 1, role: :player)
  end

  # --- Subscribe behaviour --------------------------------------------

  test "TV subscribes with code only and streams from the input stream" do
    subscribe code: @room.code
    assert subscription.confirmed?
    assert_has_stream "#{@room.channel_name}:input"
  end

  test "phone subscribes with code + valid slot but does not stream" do
    subscribe code: @room.code, slot: 1
    assert subscription.confirmed?
    assert_empty subscription.streams,
      "phones should not stream_from the input stream (they only send)"
  end

  test "subscribe rejects unknown code" do
    subscribe code: "XXXX", slot: 1
    assert subscription.rejected?
  end

  test "subscribe rejects expired rooms" do
    @room.update_column(:expires_at, 1.minute.ago)
    subscribe code: @room.code, slot: 1
    assert subscription.rejected?
  end

  test "phone subscribe rejects slot without a membership" do
    subscribe code: @room.code, slot: 3
    assert subscription.rejected?
  end

  test "phone subscribe rejects out-of-range slot" do
    subscribe code: @room.code, slot: 9
    assert subscription.rejected?
  end

  # --- Input routing ---------------------------------------------------

  test "phone #input broadcasts a normalized payload on the input stream" do
    subscribe code: @room.code, slot: 1

    stream = "#{@room.channel_name}:input"
    before = broadcasts(stream).size
    perform :input, "type" => "keydown", "input" => "up"
    msgs   = broadcasts(stream)
    assert_equal before + 1, msgs.size

    payload = JSON.parse(msgs.last)
    assert_equal 1,          payload["slot"]
    assert_equal "keydown",  payload["type"]
    assert_equal "up",       payload["input"]
  end

  test "phone #input ignores unknown input names" do
    subscribe code: @room.code, slot: 1
    stream = "#{@room.channel_name}:input"
    before = broadcasts(stream).size
    perform :input, "type" => "keydown", "input" => "hack"
    assert_equal before, broadcasts(stream).size
  end

  test "phone #input ignores unknown event types" do
    subscribe code: @room.code, slot: 1
    stream = "#{@room.channel_name}:input"
    before = broadcasts(stream).size
    perform :input, "type" => "mousedown", "input" => "up"
    assert_equal before, broadcasts(stream).size
  end

  test "TV subscription cannot send inputs (no slot => no broadcast)" do
    subscribe code: @room.code
    stream = "#{@room.channel_name}:input"
    before = broadcasts(stream).size
    perform :input, "type" => "keydown", "input" => "up"
    assert_equal before, broadcasts(stream).size
  end

  test "inputs are accepted for every occupied slot" do
    @room.memberships.create!(name: "DANI", slot: 2, role: :player)
    stream = "#{@room.channel_name}:input"

    subscribe code: @room.code, slot: 1
    perform :input, "type" => "keydown", "input" => "up"
    payload = JSON.parse(broadcasts(stream).last)
    assert_equal 1, payload["slot"]

    subscribe code: @room.code, slot: 2
    perform :input, "type" => "keydown", "input" => "left"
    payload = JSON.parse(broadcasts(stream).last)
    assert_equal 2,      payload["slot"]
    assert_equal "left", payload["input"]
  end
end
