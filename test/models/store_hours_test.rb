require "test_helper"

class StoreHoursTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  ZONE = "Australia/Brisbane".freeze

  def setup
    Counter.where(key: "store_open_until").delete_all
  end

  def teardown
    travel_back
  end

  # ── Weekday rules (Mon-Fri normal hours: 4pm-7:30pm) ─────────────────────

  test "weekday closed before 4pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 11, 30)  # Mon 11:30am
    refute StoreHours.open?
  end

  test "weekday closed at 3:59pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 15, 59)  # Mon 3:59pm
    refute StoreHours.open?
  end

  test "weekday open at 4:00pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 16, 0)  # Mon 4:00pm
    assert StoreHours.open?
  end

  test "weekday open at 7:29pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 19, 29)  # Mon 7:29pm
    assert StoreHours.open?
  end

  test "weekday closed at 7:30pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 19, 30)  # Mon 7:30pm
    refute StoreHours.open?
  end

  test "weekday closed late night" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 23, 0)  # Mon 11pm
    refute StoreHours.open?
  end

  # ── Saturday rules (7:30am-7:30pm) ────────────────────────────────────────

  test "saturday closed before 7:30am" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 9, 7, 0)  # Sat 7:00am
    refute StoreHours.open?
  end

  test "saturday open at 7:30am" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 9, 7, 30)  # Sat 7:30am
    assert StoreHours.open?
  end

  test "saturday open mid-afternoon" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 9, 14, 0)  # Sat 2pm
    assert StoreHours.open?
  end

  test "saturday closed at 7:30pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 9, 19, 30)  # Sat 7:30pm
    refute StoreHours.open?
  end

  # ── Sunday rules (7:30am-5pm) ─────────────────────────────────────────────

  test "sunday open at 7:30am" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 7, 30)  # Sun 7:30am
    assert StoreHours.open?
  end

  test "sunday open at 4:59pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 16, 59)  # Sun 4:59pm
    assert StoreHours.open?
  end

  test "sunday closed at 5:00pm" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 17, 0)  # Sun 5:00pm
    refute StoreHours.open?
  end

  test "sunday closed early evening" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 10, 18, 0)  # Sun 6pm
    refute StoreHours.open?
  end

  # ── Holiday weekdays (treat as Saturday hours: 7:30am-7:30pm) ─────────────

  test "holiday weekday open at 8am (would be closed normally)" do
    travel_to Time.find_zone(ZONE).local(2026, 4, 7, 8, 0)  # Tue in autumn holidays
    assert StoreHours.open?
  end

  test "holiday weekday closed before 7:30am" do
    travel_to Time.find_zone(ZONE).local(2026, 4, 7, 7, 0)  # Tue in autumn holidays
    refute StoreHours.open?
  end

  test "holiday weekday closed at 7:30pm" do
    travel_to Time.find_zone(ZONE).local(2026, 4, 7, 19, 30)  # Tue in autumn holidays
    refute StoreHours.open?
  end

  test "holiday end date is inclusive" do
    travel_to Time.find_zone(ZONE).local(2026, 4, 21, 8, 0)  # Last day of holidays
    assert StoreHours.open?
  end

  test "day after holiday returns to normal weekday hours" do
    travel_to Time.find_zone(ZONE).local(2026, 4, 22, 8, 0)  # Wed after holidays
    refute StoreHours.open?
    travel_to Time.find_zone(ZONE).local(2026, 4, 22, 16, 0)  # Wed 4pm
    assert StoreHours.open?
  end

  # ── Override (Counter store_open_until) ───────────────────────────────────

  test "override unlocks store outside normal hours" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 23, 0)  # Mon 11pm
    refute StoreHours.open?
    Counter.create!(key: "store_open_until", value: (Time.now + 30 * 60).to_i)
    assert StoreHours.open?
  end

  test "expired override does not unlock" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 23, 0)  # Mon 11pm
    Counter.create!(key: "store_open_until", value: (Time.now - 60).to_i)
    refute StoreHours.open?
  end

  test "override does not affect already-open hours" do
    travel_to Time.find_zone(ZONE).local(2026, 5, 4, 17, 0)  # Mon 5pm — open
    Counter.create!(key: "store_open_until", value: (Time.now - 60).to_i)
    assert StoreHours.open?, "store should still be open during regular hours"
  end

  # ── Override active? helper ───────────────────────────────────────────────

  test "override_active? false when no record" do
    refute StoreHours.override_active?
  end

  test "override_active? true when future" do
    Counter.create!(key: "store_open_until", value: (Time.now + 60).to_i)
    assert StoreHours.override_active?
  end

  test "override_active? false when past" do
    Counter.create!(key: "store_open_until", value: (Time.now - 60).to_i)
    refute StoreHours.override_active?
  end
end
