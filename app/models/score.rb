class Score < ApplicationRecord
  belongs_to :player, optional: true
  GAME_SORT = {
    "space-dodge" => :desc,
    "bloom" => :asc,
    "cat-vs-mouse" => :desc,
    "dodgeball" => :desc,
    "descent" => :asc,
    "corrupted" => :desc,
    "az-cipher" => :desc,
    "trivia" => :desc,
    "spotlight" => :desc,
    "treasure-hunt" => :desc,
    "hacker-pro" => :asc,
    "boomerang-brawl" => :desc,
    "letterbox" => :desc,
    "magnet-lab" => :desc,
    "marble-run" => :asc,
    "dino-jump"  => :desc,
    "late-shift" => :desc,
    "snake-pit-royale" => :desc,
    "golden-goal" => :desc,
    "laser-turtle" => :desc,
    "mutant-mile" => :desc,
    "dino-trails" => :asc
  }.freeze

  DEFAULT_NAMES = {
    "space-dodge" => "C&C",
    "bloom" => "ANON",
    "cat-vs-mouse" => "ANON",
    "dodgeball" => "LACHIE",
    "descent" => "ANON",
    "corrupted" => "COOPER",
    "az-cipher" => "JAYKILL",
    "letterbox" => "JAYKILL",
    "magnet-lab" => "JAYKILL",
    "late-shift" => "AZ",
    "snake-pit-royale" => "AZ",
    "golden-goal" => "AZ",
    "laser-turtle" => "TORRIN",
    "mutant-mile" => "JAYKILL",
    "dino-trails" => "JAYKILL"
  }.freeze

  validates :game, presence: true, inclusion: { in: GAME_SORT.keys }
  validates :value, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :name, presence: true

  before_validation :normalize_name

  # The top ten *players*, not the top ten attempts -- one row each, showing
  # their personal best.
  #
  # Without this a kid who plays a lot takes the whole board: on production
  # space-dodge, one player held 9 of the 10 slots, so nobody else could see
  # themselves on it. Nothing is lost by collapsing them, because a signed-in
  # player's own attempt history is returned separately as `my_scores`.
  #
  # Returns an Array rather than a relation on purpose: the query is grouped,
  # and `.count` on a grouped relation returns a Hash per group, which is a
  # trap for callers expecting a number.
  def self.top_10(game)
    direction = GAME_SORT.fetch(game, :desc)
    agg       = direction == :asc ? "MIN" : "MAX"

    where(game: game)
      .select("name, #{agg}(value) AS value")
      .group(:name)
      .order(Arel.sql("#{agg}(value) #{direction == :asc ? 'ASC' : 'DESC'}"))
      .limit(10)
      .to_a
  end

  private

  def normalize_name
    self.name = name.to_s.strip
    self.name = DEFAULT_NAMES[game] if name.blank? && game.present?
    self.name = name.to_s.upcase[0, 12]
  end
end
