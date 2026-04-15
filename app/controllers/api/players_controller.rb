module Api
  class PlayersController < ApplicationController
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

    # GET /api/players/check?username=FOO
    # Returns whether the username already exists (so the client can show Login vs Register)
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
