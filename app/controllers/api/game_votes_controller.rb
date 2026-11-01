module Api
  class GameVotesController < BaseController
    def index
      votes  = GameVote.group(:game_slug).count
      my_votes = current_player ? current_player.game_votes.pluck(:game_slug) : []
      render json: { votes: votes, my_votes: my_votes }
    end

    def create
      unless current_player
        render json: { error: "Log in to vote." }, status: :unauthorized
        return
      end

      slug = params[:game_slug].to_s.strip
      unless Game.find(slug)
        render json: { error: "Unknown game." }, status: :unprocessable_entity
        return
      end

      vote = current_player.game_votes.find_by(game_slug: slug)
      if vote
        vote.destroy
        voted = false
      else
        current_player.game_votes.create!(game_slug: slug)
        voted = true
      end

      render json: { voted: voted, count: GameVote.where(game_slug: slug).count, game_slug: slug }
    end
  end
end
