module Api
  class SessionsController < ApplicationController
    # GET /api/sessions
    # Returns current logged-in player or null
    def show
      if current_player
        render json: { player: { id: current_player.id, username: current_player.username } }
      else
        render json: { player: nil }
      end
    end

    # POST /api/sessions
    # Body: { username, pin }
    def create
      username = params[:username].to_s.strip.upcase
      player   = Player.find_by(username: username)

      unless player
        return render json: { error: "Username not found" }, status: :unauthorized
      end

      if player.locked?
        mins = (player.lockout_remaining_seconds / 60.0).ceil
        return render json: { error: "Too many attempts. Try again in #{mins} minute#{"s" unless mins == 1}." }, status: :too_many_requests
      end

      if player.authenticate_pin(params[:pin].to_s)
        player.reset_failed_attempts!
        session[:player_id] = player.id
        render json: { player: { id: player.id, username: player.username } }
      else
        player.record_failed_attempt!
        remaining = Player::MAX_ATTEMPTS - player.failed_attempts
        if player.locked?
          render json: { error: "Too many wrong PINs. Locked for #{Player::LOCKOUT_MINUTES} minutes." }, status: :too_many_requests
        else
          render json: { error: "Wrong PIN. #{remaining} attempt#{"s" unless remaining == 1} left." }, status: :unauthorized
        end
      end
    end

    # DELETE /api/sessions
    def destroy
      session.delete(:player_id)
      render json: { ok: true }
    end
  end
end
