require "test_helper"

class CounterTest < ActiveSupport::TestCase
  setup do
    Counter.delete_all
  end

  test "increment_and_get creates counter if missing" do
    count = Counter.increment_and_get("visitors")
    assert_equal 1, count
    assert_equal 1, Counter.find_by(key: "visitors").value
  end

  test "increment_and_get increments existing counter" do
    Counter.create!(key: "visitors", value: 41)
    count = Counter.increment_and_get("visitors")
    assert_equal 42, count
  end

  test "increment_and_get is atomic" do
    Counter.create!(key: "visitors", value: 0)
    3.times { Counter.increment_and_get("visitors") }
    assert_equal 3, Counter.find_by(key: "visitors").value
  end

  test "validates uniqueness of key" do
    Counter.create!(key: "visitors", value: 0)
    dup = Counter.new(key: "visitors", value: 0)
    assert_not dup.valid?
  end
end
