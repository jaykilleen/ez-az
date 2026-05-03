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

    def destroy
      code = params[:code].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 4]
      room = Room.active.find_by(code: code)
      return render(json: { error: "Room not found" }, status: :not_found) unless room

      if room.tv_token.present?
        ActionCable.server.broadcast("tv_remote:#{room.tv_token}", { type: "tv_home" })
      end
      room.update!(expires_at: 1.minute.ago)
      render json: { ok: true }
    end
  end
end
