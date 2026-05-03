module Api
  class ActiveRoomsController < BaseController
    GAME_TITLES = {
      "trivia"        => "Family Trivia",
      "spotlight"     => "Spotlight",
      "treasure-hunt" => "Treasure Hunt",
      "hacker-pro"    => "Hacker Pro"
    }.freeze

    def index
      response.headers["Cache-Control"] = "no-store"
      rooms = Room.active.where.not(game_slug: nil).order(updated_at: :desc).limit(20)
      render json: {
        rooms: rooms.map { |r|
          {
            code:         r.code,
            game_slug:    r.game_slug,
            game_title:   GAME_TITLES[r.game_slug] || r.game_slug,
            member_count: r.memberships.where(role: :player).count
          }
        }
      }
    end
  end
end
