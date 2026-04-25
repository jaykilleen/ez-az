class TvRemoteController < ApplicationController
  layout "controller"

  def show
    response.headers["Cache-Control"] = "no-store"
    if params[:code].present? && params[:token].blank?
      code  = params[:code].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 4]
      @room = Room.active.find_by(code: code)
      return redirect_to("/", status: :see_other) unless @room
      @token     = @room.tv_token
      @room_code = @room.code
    else
      @token = params[:token].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 8]
      return redirect_to tv_path if @token.blank?
      @room      = Room.active.find_by(tv_token: @token)
      @room_code = @room&.code
    end
  end
end
