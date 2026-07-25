# Server-side mirror of public/opening-hours.js. Both must agree on when the
# store is open so the client redirect and the server enforcement don't
# disagree. If you change the rules here, change the JS too.
#
# Normal hours (Brisbane / no DST):
#   Mon-Fri  4:00pm  - 7:30pm
#   Sat      7:30am - 7:30pm
#   Sun      7:30am - 5:00pm
#
# During school holidays, weekdays swap to Saturday hours.
# An after-hours override is set via Counter("store_open_until") — used by the
# Cipher unlock flow so kids who solve it can play after closing.
class StoreHours
  ZONE = "Australia/Brisbane".freeze

  # Queensland state school holidays -- every non-term weekday block.
  # Source: https://education.qld.gov.au/about-us/calendar/term-dates
  # (2027+ dates come from the "future school dates" page.)
  #
  # MUST stay identical to HOLIDAYS in public/opening-hours.js.
  # StoreHoursTest guards both the drift and the expiry:
  #   - "ruby and js holiday tables agree" fails if the two lists diverge
  #   - "holiday coverage extends into the future" fails once the data is
  #     within 30 days of running out, so we top it up BEFORE a break starts
  #     rather than after the kids find the store shut.
  HOLIDAYS = [
    { from: "2026-04-03", to: "2026-04-19" },  # Autumn 2026
    { from: "2026-06-27", to: "2026-07-12" },  # Winter 2026
    { from: "2026-09-19", to: "2026-10-05" },  # Spring 2026
    { from: "2026-12-12", to: "2027-01-26" },  # Summer 2026/27
    { from: "2027-03-26", to: "2027-04-11" },  # Autumn 2027
    { from: "2027-06-26", to: "2027-07-11" },  # Winter 2027
    { from: "2027-09-18", to: "2027-10-04" },  # Spring 2027
    { from: "2027-12-11", to: "2028-01-23" }   # Summer 2027/28
  ].freeze

  WEEKDAY_OPEN  = 16 * 60       # 4:00pm
  WEEKEND_OPEN  = 7 * 60 + 30   # 7:30am
  CLOSE_730PM   = 19 * 60 + 30  # 7:30pm
  CLOSE_500PM   = 17 * 60       # 5:00pm

  def self.open?(at = Time.zone.now)
    override_active?(at) || scheduled_open?(at)
  end

  # Open according to the published timetable, ignoring any override.
  def self.scheduled_open?(at = Time.zone.now)
    local   = at.in_time_zone(ZONE)
    minutes = local.hour * 60 + local.min
    window  = window_for(local)
    minutes >= window[:open_min] && minutes < window[:close_min]
  end

  # Which timetable applies on the given day, and the minutes-from-midnight it
  # runs between. Single source of truth for the rules -- open? and status both
  # go through here so they can't disagree.
  def self.window_for(at)
    local = at.in_time_zone(ZONE)
    case local.wday
    when 0 then { schedule: "sunday",   open_min: WEEKEND_OPEN, close_min: CLOSE_500PM }
    when 6 then { schedule: "saturday", open_min: WEEKEND_OPEN, close_min: CLOSE_730PM }
    else
      if on_holiday?(local)
        { schedule: "holiday", open_min: WEEKEND_OPEN, close_min: CLOSE_730PM }
      else
        { schedule: "weekday", open_min: WEEKDAY_OPEN, close_min: CLOSE_730PM }
      end
    end
  end

  # The unix timestamp an active override runs until, or nil when there isn't
  # one. An after-hours override is a Counter named "store_open_until" holding
  # a timestamp in the future -- used by the Cipher unlock flow so kids who
  # solve it can play after closing.
  def self.override_until(at = Time.zone.now)
    counter = Counter.find_by(key: "store_open_until")
    return nil unless counter && counter.value > at.to_i
    counter.value
  end

  def self.override_active?(at = Time.zone.now)
    !override_until(at).nil?
  end

  def self.holiday_for(at)
    iso = at.in_time_zone(ZONE).strftime("%Y-%m-%d")
    HOLIDAYS.find { |h| iso >= h[:from] && iso <= h[:to] }
  end

  def self.on_holiday?(at)
    !holiday_for(at).nil?
  end

  # Everything a caller needs to understand why the store is open or shut.
  # Served by /api/store/status so the timetable is observable in production
  # instead of only in the test suite.
  def self.status(at = Time.zone.now)
    local    = at.in_time_zone(ZONE)
    window   = window_for(local)
    holiday  = holiday_for(local)
    until_ts = override_until(at)

    {
      open:       !until_ts.nil? || scheduled_open?(at),
      override:   !until_ts.nil?,
      open_until: until_ts,
      schedule:   window[:schedule],
      opens_at:   clock(window[:open_min]),
      closes_at:  clock(window[:close_min]),
      holiday:    holiday && { from: holiday[:from], to: holiday[:to] },
      now:        local.iso8601,
      zone:       ZONE
    }
  end

  def self.clock(minutes)
    format("%02d:%02d", minutes / 60, minutes % 60)
  end
  private_class_method :clock
end
