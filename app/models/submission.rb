class Submission < ApplicationRecord
  STATES = %w[pending approved rejected].freeze
  SCORE_DIRECTIONS = %w[desc asc].freeze
  SLUG_FORMAT = /\A[a-z0-9]+(-[a-z0-9]+)*\z/
  RESERVED_SLUGS = (Score::GAME_SORT.keys + %w[trivia spotlight treasure-hunt]).freeze
  MAX_HTML_BYTES = 1_000_000  # 1 MB
  MAX_TITLE_LEN  = 60
  MAX_TAGLINE_LEN = 200
  MAX_NOTES_LEN  = 2000

  validates :slug,
            presence: true,
            format: { with: SLUG_FORMAT, message: "must be lowercase letters, digits, single hyphens (3-24 chars)" },
            length: { in: 3..24 }
  validates :title,           presence: true, length: { maximum: MAX_TITLE_LEN }
  validates :creators,        presence: true, length: { maximum: 80 }
  validates :tagline,         presence: true, length: { maximum: MAX_TAGLINE_LEN }
  validates :score_direction, presence: true, inclusion: { in: SCORE_DIRECTIONS }
  validates :game_html,       presence: true
  validates :contact_email,   presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email" }
  validates :notes,           length: { maximum: MAX_NOTES_LEN }, allow_nil: true
  validates :status,          inclusion: { in: STATES }

  validate :slug_not_reserved
  validate :game_html_size

  scope :pending,  -> { where(status: "pending").order(created_at: :desc) }
  scope :reviewed, -> { where.not(status: "pending").order(reviewed_at: :desc) }

  def pending?  = status == "pending"
  def approved? = status == "approved"
  def rejected? = status == "rejected"

  # Quick checks for the admin queue — non-blocking, just informational.
  def html_warnings
    warnings = []
    warnings << "missing store banner (link to /)" unless game_html.include?('href="/"') || game_html.include?("href='/'")
    warnings << "no /api/scores call (leaderboard not wired)" if !is_chill && !game_html.include?("/api/scores")
    warnings << "no Escape pause / quit handler" unless game_html.match?(/Escape|key.*Esc/i)
    warnings << "external script tag (must be self-contained)" if game_html.match?(%r{<script[^>]+src=["']https?://}i)
    warnings
  end

  private

  def slug_not_reserved
    return unless slug.present?
    if RESERVED_SLUGS.include?(slug)
      errors.add(:slug, "is already taken — pick a different slug")
    end
  end

  def game_html_size
    return unless game_html.present?
    if game_html.bytesize > MAX_HTML_BYTES
      errors.add(:game_html, "is too large (#{game_html.bytesize} bytes, max #{MAX_HTML_BYTES})")
    end
  end
end
