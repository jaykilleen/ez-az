class Player < ApplicationRecord
  has_secure_password :pin

  MAX_ATTEMPTS    = 5
  LOCKOUT_MINUTES = 15

  has_many :scores

  normalizes :username, with: ->(v) { v.strip.upcase }

  validates :username,
    presence: true,
    uniqueness: true,
    length: { maximum: 16 },
    format: { with: /\A[A-Z0-9_]+\z/, message: "letters, numbers and underscores only" }

  validates :pin,
    format: { with: /\A\d{4}\z/, message: "must be exactly 4 digits" },
    allow_nil: true

  def locked?
    locked_until.present? && locked_until > Time.current
  end

  def lockout_remaining_seconds
    return 0 unless locked?
    (locked_until - Time.current).ceil
  end

  def record_failed_attempt!
    new_count = failed_attempts + 1
    attrs = { failed_attempts: new_count }
    attrs[:locked_until] = LOCKOUT_MINUTES.minutes.from_now if new_count >= MAX_ATTEMPTS
    update_columns(attrs)
  end

  def reset_failed_attempts!
    update_columns(failed_attempts: 0, locked_until: nil)
  end
end
