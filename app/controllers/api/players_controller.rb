module Api
  class PlayersController < BaseController
    # POST /api/players
    # Body: { username, pin }
    def create
      username = params[:username].to_s.strip.upcase
      pin      = params[:pin].to_s.strip

      player = Player.new(username: username, pin: pin, pin_confirmation: pin)

      if player.save
        session[:player_id] = player.id
        render json: player_json(player), status: :created
      else
        render json: { error: player.errors.full_messages.first }, status: :unprocessable_entity
      end
    end

    # POST /api/players/claim
    # Body: { username }
    # One-tap identity claim — no pin required. Returns device_token once.
    def claim
      username = params[:username].to_s.strip
      return render json: { error: "Name required" }, status: :unprocessable_entity if username.blank?

      if Player.exists?(username: username.upcase.gsub(/[^A-Z0-9_]/, "").first(16))
        return render json: { error: "Name taken — try another" }, status: :conflict
      end

      player = Player.claim!(username)
      render json: { device_token: player.device_token, username: player.username, player_id: player.id },
             status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.first }, status: :unprocessable_entity
    end

    # GET /api/players/check?username=FOO
    def check
      username = params[:username].to_s.strip.upcase
      exists   = Player.exists?(username: username)
      render json: { exists: exists }
    end

    private

    def player_json(player)
      { id: player.id, username: player.username }
    end
  end
end
