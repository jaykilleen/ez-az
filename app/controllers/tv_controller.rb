require "rqrcode"

class TvController < ApplicationController
  layout "tv"

  def show
    @games        = Game.for_tv
    @coming_to_tv = Game.coming_to_tv
    all_count     = @games.size + @coming_to_tv.size
    @tv_cols      = [[all_count, 1].max, 5].min
    @version      = EzAz::Version::STRING

    @room = Room.create_tv_session!

    remote_url = tv_remote_url(token: @room.tv_token, code: @room.code, v: @version)
    svg = RQRCode::QRCode.new(remote_url).as_svg(
      color: "00ffc8",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true,
      use_path: true
    )
    svg = svg.sub(/<\?xml[^?]*\?>/, "")
             .sub(/width="(\d+)" height="(\d+)"/, 'width="100%" height="100%" viewBox="0 0 \1 \2"')
    @qr_code_svg = svg.html_safe
  end
end
