require "test_helper"

class ErrorReportTest < ActiveSupport::TestCase
  setup do
    ErrorReport.delete_all
  end

  test "record! creates a new report on first sighting" do
    assert_difference -> { ErrorReport.count }, 1 do
      ErrorReport.record!(message: "boom", stack: "at foo (x:1)", game: "bloom")
    end
    r = ErrorReport.last
    assert_equal "boom",         r.message
    assert_equal "at foo (x:1)", r.stack
    assert_equal "bloom",        r.game
    assert_equal 1, r.occurrences
    assert_not_nil r.fingerprint
  end

  test "record! dedups by fingerprint and bumps occurrences + last_seen_at" do
    r1 = ErrorReport.record!(message: "boom", stack: "at foo (x:1)", game: "bloom")
    assert_equal 1, r1.occurrences

    r2 = ErrorReport.record!(message: "boom", stack: "at foo (x:1)", game: "bloom")
    assert_equal r1.id, r2.id
    assert_equal 2, r2.occurrences
    assert_operator r2.last_seen_at, :>=, r1.last_seen_at
  end

  test "different messages fingerprint separately" do
    a = ErrorReport.record!(message: "boom",  stack: "at foo (x:1)", game: "bloom")
    b = ErrorReport.record!(message: "crash", stack: "at foo (x:1)", game: "bloom")
    assert_not_equal a.fingerprint, b.fingerprint
    assert_equal 2, ErrorReport.count
  end

  test "different games fingerprint separately even for the same error" do
    a = ErrorReport.record!(message: "boom", stack: "at foo (x:1)", game: "bloom")
    b = ErrorReport.record!(message: "boom", stack: "at foo (x:1)", game: "descent")
    assert_not_equal a.fingerprint, b.fingerprint
  end

  test "different top stack frames fingerprint separately" do
    a = ErrorReport.record!(message: "TypeError", stack: "at foo (a.js:1)", game: nil)
    b = ErrorReport.record!(message: "TypeError", stack: "at bar (b.js:1)", game: nil)
    assert_not_equal a.fingerprint, b.fingerprint
  end

  test "blank messages are silently dropped" do
    assert_nil ErrorReport.record!(message: "",   stack: "whatever")
    assert_nil ErrorReport.record!(message: "   ", stack: "whatever")
    assert_nil ErrorReport.record!(message: nil,  stack: "whatever")
    assert_equal 0, ErrorReport.count
  end

  test "overlong messages are truncated to MESSAGE_MAX" do
    long = "x" * (ErrorReport::MESSAGE_MAX + 50)
    r = ErrorReport.record!(message: long, stack: "")
    assert_equal ErrorReport::MESSAGE_MAX, r.message.length
  end

  test "overlong stacks are truncated to STACK_MAX" do
    long = "y" * (ErrorReport::STACK_MAX + 5_000)
    r = ErrorReport.record!(message: "boom", stack: long)
    assert_equal ErrorReport::STACK_MAX, r.stack.length
  end

  test "recent scope orders by last_seen_at desc" do
    old = ErrorReport.record!(message: "old",   stack: "a")
    old.update!(last_seen_at: 1.hour.ago)
    new = ErrorReport.record!(message: "new",   stack: "b")

    assert_equal [new.id, old.id], ErrorReport.recent.limit(2).pluck(:id)
  end
end
