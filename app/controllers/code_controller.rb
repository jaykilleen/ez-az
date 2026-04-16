# Public code inspector (#34). Kids can browse how EZ-AZ and its games
# are actually built, with syntax highlighting and line numbers.
#
# Security: only paths in CURATED are ever served. The `path` param is
# compared against the whitelist's relative paths — anything outside is
# a 404. We never call File.read with an unvalidated user-supplied path.
class CodeController < ApplicationController
  # Each entry: { path:, label:, blurb:, category: }
  # `path` is relative to Rails.root; `category` groups the index.
  CURATED = [
    # --- Games: the fun stuff, probably most interesting to kids ---
    { path: "public/games/space-dodge.html",  label: "Space Dodge",
      blurb: "Charlie & Cooper's co-op space shooter — bosses, power-ups, robot voice",
      category: "Games" },
    { path: "public/games/dodgeball.html",    label: "Dodgeball '88",
      blurb: "Lachie's top-down 2v2 tournament with a wandering ref and ball boys",
      category: "Games" },
    { path: "public/games/corrupted.html",    label: "Corrupted",
      blurb: "Cooper's first-person zombie fighter — raycasting in plain JS",
      category: "Games" },
    { path: "public/games/descent.html",      label: "Descent",
      blurb: "Jaykill's maze runner with flashlight vision and fog of war",
      category: "Games" },
    { path: "public/games/cat-vs-mouse.html", label: "Cat vs Mouse",
      blurb: "Lil's rope-puzzle game across eight levels",
      category: "Games" },
    { path: "public/games/bloom.html",        label: "Bloom",
      blurb: "Az's chill exploration game — time-based scoring, no pressure",
      category: "Games" },

    # --- Shared frontend plumbing ---
    { path: "public/index.html",           label: "The store (index.html)",
      blurb: "The EZ-AZ store page — leaderboard, visitor counter, login modal, and the Az dinosaur",
      category: "Store frontend" },
    { path: "public/controls.js",          label: "Touch controls",
      blurb: "Virtual joystick + action buttons that make keyboard games playable on phones",
      category: "Store frontend" },
    { path: "public/game-viewport.js",     label: "Game viewport helper",
      blurb: "Scales each game's canvas to fit any screen without upscaling on desktop",
      category: "Store frontend" },
    { path: "public/opening-hours.js",     label: "Opening hours",
      blurb: "Checks if the store is open, handles school-holiday hours, and redirects to /closed.html",
      category: "Store frontend" },
    { path: "public/error-reporter.js",    label: "Error reporter",
      blurb: "Catches runtime errors and sends them to /api/errors for the public error tracker",
      category: "Store frontend" },
    { path: "app/views/room_input/show.js.erb", label: "Multiplayer input router",
      blurb: "TV-side script that turns WebSocket messages from phones into keyboard events (served by Rails as /room-input.js)",
      category: "Store frontend" },

    # --- Rails backend ---
    { path: "config/routes.rb",                              label: "All the routes",
      blurb: "Every URL in EZ-AZ — start here if you want to see what the backend can do",
      category: "Rails backend" },
    { path: "app/models/score.rb",                           label: "Score model",
      blurb: "Per-game leaderboard rows with name normalisation and per-game sort direction",
      category: "Rails backend" },
    { path: "app/models/error_report.rb",                    label: "Error report model",
      blurb: "How the error tracker dedups by message + stack + game to avoid duplicates",
      category: "Rails backend" },
    { path: "app/controllers/api/base_controller.rb",        label: "Api::BaseController",
      blurb: "JSON-everything error handling so the client always gets a parseable response",
      category: "Rails backend" },
    { path: "app/controllers/api/scores_controller.rb",      label: "Scores API",
      blurb: "GET/POST /api/scores — the endpoint every game hits to save high scores",
      category: "Rails backend" },
    { path: "app/channels/controller_channel.rb",            label: "Controller channel",
      blurb: "The ActionCable channel that routes phone inputs to the TV in real time",
      category: "Rails backend" },
    { path: "app/controllers/rooms_controller.rb",           label: "Rooms controller",
      blurb: "Create a room, join it from a phone, pick a game, start it on the TV",
      category: "Rails backend" }
  ].freeze

  def index
    @grouped = CURATED.group_by { |entry| entry[:category] }
    @github_repo = "jaykilleen/easy-az"
  end

  def show
    path = params[:path].to_s
    entry = CURATED.find { |e| e[:path] == path }

    raise ActionController::RoutingError, "Not in the code inspector" unless entry

    full_path = Rails.root.join(entry[:path])
    raise ActionController::RoutingError, "File moved" unless File.exist?(full_path)

    @entry       = entry
    @source      = File.read(full_path)
    @github_repo = "jaykilleen/easy-az"
    @github_url  = "https://github.com/#{@github_repo}/blob/main/#{entry[:path]}"
    @language    = language_for(entry[:path])
  end

  private

  def language_for(path)
    case File.extname(path)
    when ".rb"    then "ruby"
    when ".html", ".html.erb", ".erb" then "markup"
    when ".js"    then "javascript"
    when ".json"  then "json"
    when ".css"   then "css"
    when ".yml", ".yaml" then "yaml"
    else "plaintext"
    end
  end
end
