require "digest/sha1"

class ErrorReport < ApplicationRecord
  MESSAGE_MAX = 500
  STACK_MAX   = 10_000    # plenty for a typical JS stack, protects the DB

  validates :fingerprint,   presence: true, uniqueness: true
  validates :message,       presence: true
  validates :occurrences,   numericality: { greater_than: 0 }
  validates :first_seen_at, :last_seen_at, presence: true

  scope :recent,     -> { order(last_seen_at: :desc) }
  scope :for_game,   ->(game) { where(game: game) }

  # Given the raw client payload, build-or-update the matching ErrorReport.
  # Dedups by fingerprint: same message + top stack frame + game = same
  # report, just with a higher occurrence count.
  def self.record!(attrs)
    attrs = attrs.with_indifferent_access
    message = attrs[:message].to_s.strip
    return nil if message.blank?

    message = message[0, MESSAGE_MAX]
    stack   = attrs[:stack].to_s[0, STACK_MAX]
    game    = attrs[:game].to_s.presence
    fp      = fingerprint_for(message: message, stack: stack, game: game)

    now = Time.current
    record = find_or_initialize_by(fingerprint: fp)

    if record.new_record?
      record.assign_attributes(
        message:       message,
        stack:         stack,
        game:          game,
        user_agent:    attrs[:user_agent].to_s[0, MESSAGE_MAX].presence,
        url:           attrs[:url].to_s[0, MESSAGE_MAX].presence,
        first_seen_at: now,
        last_seen_at:  now,
        occurrences:   1
      )
      record.save!
    else
      # Atomic: don't fetch the counter Ruby-side, let SQLite handle it.
      where(id: record.id).update_all([
        "occurrences = occurrences + 1, last_seen_at = ?, updated_at = ?",
        now, now
      ])
      record.reload
    end

    record
  end

  # Deterministic fingerprint keyed on the high-signal bits: message,
  # first stack frame, game. Different games throwing the same
  # "undefined is not a function" are still treated as different bugs.
  def self.fingerprint_for(message:, stack:, game:)
    first_frame = stack.to_s.lines.first.to_s.strip
    Digest::SHA1.hexdigest("#{message}\0#{first_frame}\0#{game}")[0, 16]
  end
end
