class GameVote < ApplicationRecord
  belongs_to :player

  validates :game_slug, presence: true
  validates :game_slug, uniqueness: { scope: :player_id }
end
