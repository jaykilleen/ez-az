module Api
  class ScoresController < ApplicationController
    def index
      game = params[:game]

      unless Score::GAME_SORT.key?(game)
        return render json: { error: "Unknown game" }, status: :bad_request
      end

      scores = Score.top_10(game).pluck(:name, :value).map { |n, v| { "name" => n, "value" => v } }
      response.headers["Cache-Control"] = "no-store"
      render json: { scores: scores }
    end

    def create
      body = JSON.parse(request.body.read) rescue {}
      game = body["game"].to_s
      name = body["name"].to_s
      value = body["value"].to_i

      unless Score::GAME_SORT.key?(game)
        return render json: { error: "Unknown game" }, status: :bad_request
      end

      if value <= 0
        return render json: { error: "Value must be positive" }, status: :bad_request
      end

      Score.create!(game: game, name: name, value: value)

      scores = Score.top_10(game).pluck(:name, :value).map { |n, v| { "name" => n, "value" => v } }
      render json: { scores: scores }, status: :created
    end
  end
end
