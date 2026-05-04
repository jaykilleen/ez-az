require "rqrcode"

class TriviaController < ApplicationController
  include RespectsStoreHours
  layout "tv"

  def new
    room = Room.create!(game_slug: "trivia", tv_token: SecureRandom.alphanumeric(8).upcase)
    redirect_to trivia_path(room.code)
  end

  def show
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return redirect_to new_trivia_path unless @room

    @room.update!(tv_token: SecureRandom.alphanumeric(8).upcase) unless @room.tv_token.present?
    @members = @room.memberships.where(role: :player).order(:slot)

    svg = RQRCode::QRCode.new(tv_remote_url(token: @room.tv_token, code: @room.code, v: EzAz::Version::STRING)).as_svg(
      color: "00ffc8",
      module_size: 6,
      standalone: true,
      use_path: true
    )
    svg = svg.sub(/<\?xml[^?]*\?>/, "")
             .sub(/width="(\d+)" height="(\d+)"/, 'width="100%" height="100%" viewBox="0 0 \1 \2"')
    @qr_code_svg = svg.html_safe
  end
end
