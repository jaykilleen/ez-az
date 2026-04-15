class ApplicationController < ActionController::Base
  skip_forgery_protection

  private

  def current_player
    @current_player ||= Player.find_by(id: session[:player_id]) if session[:player_id]
  end
  helper_method :current_player
end
