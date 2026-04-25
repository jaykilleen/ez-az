class Room < ApplicationRecord
  MAX_PLAYERS     = 4
  DEFAULT_TTL     = 4.hours
  CODE_ALPHABET   = "BCDFGHJKLMNPQRSTVWXYZ23456789".chars.freeze  # no vowels, no 0/O/1/I

  enum :state, { lobby: 0, playing: 1, finished: 2 }

  has_many :memberships, -> { order(:slot) },
           class_name: "RoomMembership",
           dependent:  :destroy,
           inverse_of: :room

  validates :code,       presence: true, uniqueness: true, format: { with: /\A[A-Z0-9]{4}\z/ }
  validates :expires_at, presence: true
  validates :game_slug,  inclusion: { in: Score::GAME_SORT.keys }, allow_nil: true

  before_validation :assign_code,       on: :create
  before_validation :assign_expires_at, on: :create

  scope :active, -> { where("expires_at > ?", Time.current) }

  def self.generate_code
    loop do
      code = Array.new(4) { CODE_ALPHABET.sample }.join
      break code unless exists?(code: code)
    end
  end

  # Create a new TV party session room.
  def self.create_tv_session!
    create!(tv_token: SecureRandom.alphanumeric(8).upcase)
  end

  def host
    memberships.find_by(role: :host)
  end

  def players
    memberships.where(role: :player)
  end

  def full?
    memberships.count >= MAX_PLAYERS
  end

  def touch_expiry!
    update!(expires_at: DEFAULT_TTL.from_now)
  end

  def next_available_slot
    used = memberships.pluck(:slot).to_set
    (1..MAX_PLAYERS).find { |s| !used.include?(s) }
  end

  # ActionCable broadcast identifier — both TV and phones stream this name.
  def channel_name
    "room:#{code}"
  end

  private

  def assign_code
    self.code ||= self.class.generate_code
  end

  def assign_expires_at
    self.expires_at ||= DEFAULT_TTL.from_now
  end
end
