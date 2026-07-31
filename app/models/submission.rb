class Submission < ApplicationRecord
  STATES = %w[pending approved rejected].freeze
  KINDS = %w[html prompt].freeze
  SCORE_DIRECTIONS = %w[desc asc].freeze
  SLUG_FORMAT = /\A[a-z0-9]+(-[a-z0-9]+)*\z/
  RESERVED_SLUGS = (Score::GAME_SORT.keys + %w[trivia spotlight treasure-hunt]).freeze
  MAX_HTML_BYTES = 1_000_000  # 1 MB
  MAX_TITLE_LEN  = 60
  MAX_TAGLINE_LEN = 200
  MAX_NOTES_LEN  = 2000
  MAX_PROMPT_LEN = 2000

  # Hard-rejected at save time, before a submission ever reaches the admin
  # queue — these are concrete, low-false-positive attack primitives (cookie
  # theft, frame/clickjacking reach, remote code load, eval-style
  # obfuscation). This is a floor, not the real defence: the actual backstop
  # is that approved submissions are still copied in by hand (ADR 007), and
  # the admin preview iframe has no allow-same-origin. A determined attacker
  # can dodge a regex; they still can't dodge a human plus a sandboxed frame.
  DANGEROUS_PATTERNS = [
    [/document\.cookie/i, "reads document.cookie"],
    [/\bwindow\.(parent|top)\b/i, "reaches outside its frame (window.parent/top)"],
    [/\btop\.location\b/i, "reaches outside its frame (top.location)"],
    [/<iframe[\s>]/i, "embeds an iframe"],
    [/\beval\s*\(/i, "uses eval()"],
    [/\bnew\s+Function\s*\(/i, "uses the Function constructor (eval-equivalent)"],
    [/\bdocument\.write\s*\(/i, "uses document.write()"],
    [/<script[^>]+src\s*=\s*["']https?:\/\//i, "loads a script from an external URL"],
    [/\b(?:fetch|XMLHttpRequest|WebSocket|EventSource)\s*\(\s*["']https?:\/\//i, "makes a network call to an absolute external URL"]
  ].freeze

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :title,           presence: true, length: { maximum: MAX_TITLE_LEN }
  validates :creators,        presence: true, length: { maximum: 80 }
  validates :contact_email,   presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email" }
  validates :notes,           length: { maximum: MAX_NOTES_LEN }, allow_nil: true
  validates :status,          inclusion: { in: STATES }

  # A "prompt" submission is just an idea in words -- no code, no slug, no
  # scoring direction yet. Those only make sense once an actual game exists.
  validates :slug,
            presence: true,
            format: { with: SLUG_FORMAT, message: "must be lowercase letters, digits, single hyphens (3-24 chars)" },
            length: { in: 3..24 },
            if: :html?
  validates :tagline,         presence: true, length: { maximum: MAX_TAGLINE_LEN }, if: :html?
  validates :score_direction, presence: true, inclusion: { in: SCORE_DIRECTIONS }, if: :html?
  validates :game_html,       presence: true, if: :html?
  validates :idea_prompt,     presence: true, length: { maximum: MAX_PROMPT_LEN }, if: :prompt?

  validate :slug_not_reserved, if: :html?
  validate :game_html_size, if: :html?
  validate :no_dangerous_patterns, if: :html?

  scope :pending,  -> { where(status: "pending").order(created_at: :desc) }
  scope :reviewed, -> { where.not(status: "pending").order(reviewed_at: :desc) }

  def pending?  = status == "pending"
  def approved? = status == "approved"
  def rejected? = status == "rejected"
  def html?     = kind == "html"
  def prompt?   = kind == "prompt"

  # Quick checks for the admin queue — non-blocking, just informational.
  # (The external-script-tag check that used to live here is now a hard
  # rejection in DANGEROUS_PATTERNS instead of an advisory warning.)
  def html_warnings
    return [] unless html?
    warnings = []
    warnings << "missing store banner (link to /)" unless game_html.include?('href="/"') || game_html.include?("href='/'")
    warnings << "no /api/scores call (leaderboard not wired)" if !is_chill && !game_html.include?("/api/scores")
    warnings << "no Escape pause / quit handler" unless game_html.match?(/Escape|key.*Esc/i)
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

  def no_dangerous_patterns
    return unless game_html.present?
    DANGEROUS_PATTERNS.each do |pattern, description|
      if game_html.match?(pattern)
        errors.add(:game_html, "was rejected: #{description}. Submitted games must be fully self-contained and can't reach outside their own page.")
        break # one clear reason is enough — don't pile on for a single bad file
      end
    end
  end
end
