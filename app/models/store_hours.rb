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
    return true if override_active?(at)
    local = at.in_time_zone(ZONE)
    minutes = local.hour * 60 + local.min
    case local.wday
    when 0 # Sunday
      minutes >= WEEKEND_OPEN && minutes < CLOSE_500PM
    when 6 # Saturday
      minutes >= WEEKEND_OPEN && minutes < CLOSE_730PM
    else
      open_at = on_holiday?(local) ? WEEKEND_OPEN : WEEKDAY_OPEN
      minutes >= open_at && minutes < CLOSE_730PM
    end
  end

  # An after-hours override is active when a Counter named "store_open_until"
  # holds a unix timestamp in the future.
  def self.override_active?(at = Time.zone.now)
    counter = Counter.find_by(key: "store_open_until")
    return false unless counter
    counter.value > at.to_i
  end

  def self.on_holiday?(at)
    iso = at.in_time_zone(ZONE).strftime("%Y-%m-%d")
    HOLIDAYS.any? { |h| iso >= h[:from] && iso <= h[:to] }
  end
end
