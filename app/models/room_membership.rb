class RoomMembership < ApplicationRecord
  NAME_MAX = 12

  belongs_to :room,   inverse_of: :memberships
  belongs_to :player, optional: true

  enum :role, { host: 0, player: 1 }

  validates :name, presence: true, length: { maximum: NAME_MAX }
  validates :slot,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: Room::MAX_PLAYERS },
            uniqueness: { scope: :room_id }

  before_validation :normalize_name

  def display
    { name: name, slot: slot, role: role, connected: connected }
  end

  private

  def normalize_name
    self.name = name.to_s.strip
    self.name = player.username if name.blank? && player
    self.name = "ANON" if name.blank?
    self.name = name.upcase[0, NAME_MAX]
  end
end
