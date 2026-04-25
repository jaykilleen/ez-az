require "rqrcode"

class TriviaController < ApplicationController
  layout "tv"

  def new
    room = Room.create!(game_slug: "trivia")
    redirect_to trivia_path(room.code)
  end

  def show
    @room = Room.active.find_by(code: params[:code].to_s.upcase)
    return redirect_to new_trivia_path unless @room

    @members = @room.memberships.where(role: :player).order(:slot)

    svg = RQRCode::QRCode.new(join_room_url(code: @room.code)).as_svg(
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
