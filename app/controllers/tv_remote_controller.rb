class TvRemoteController < ApplicationController
  layout "controller"

  def show
    @token = params[:token].to_s.upcase.gsub(/[^A-Z0-9]/, "")[0, 8]
    redirect_to tv_path if @token.blank?
  end
end
