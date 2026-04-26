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

    # POST /api/players/login
    # Body: { username, pin }
    # Returns device_token on success.
    def login
      username = params[:username].to_s.strip.upcase.gsub(/[^A-Z0-9_]/, "").first(16)
      pin      = params[:pin].to_s.strip

      player = Player.find_by(username: username)
      return render json: { error: "Name not found" }, status: :not_found unless player
      return render json: { error: "No PIN set — use your original device" }, status: :unprocessable_entity unless player.pin_digest.present?

      if player.locked?
        mins = (player.lockout_remaining_seconds / 60.0).ceil
        return render json: { error: "Too many attempts — try again in #{mins} minute#{'s' if mins != 1}", locked: true }, status: :too_many_requests
      end

      if player.authenticate_pin(pin)
        player.reset_failed_attempts!
        render json: { device_token: player.device_token, username: player.username, player_id: player.id }
      else
        player.record_failed_attempt!
        remaining = [Player::MAX_ATTEMPTS - player.reload.failed_attempts, 0].max
        if remaining == 0
          render json: { error: "Too many attempts — locked for #{Player::LOCKOUT_MINUTES} minutes", locked: true }, status: :too_many_requests
        else
          render json: { error: "Wrong PIN — #{remaining} attempt#{'s' if remaining != 1} left" }, status: :unauthorized
        end
      end
    end

    # POST /api/players/pin
    # Body: { device_token, pin }
    # Set or update a player's PIN (identified by their device_token).
    def set_pin
      device_token = params[:device_token].to_s.strip
      pin          = params[:pin].to_s.strip

      player = Player.find_by(device_token: device_token)
      return render json: { error: "Not found" }, status: :not_found unless player

      if player.update(pin: pin, pin_confirmation: pin)
        render json: { ok: true }
      else
        render json: { error: player.errors.full_messages.first }, status: :unprocessable_entity
      end
    end

    # GET /api/players/check?username=FOO
    def check
      username   = params[:username].to_s.strip.upcase
      player     = Player.find_by(username: username)
      render json: { exists: player.present?, has_pin: player&.pin_digest.present? }
    end

    private

    def player_json(player)
      { id: player.id, username: player.username }
    end
  end
end
