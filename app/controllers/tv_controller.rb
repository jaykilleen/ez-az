require "rqrcode"

class TvController < ApplicationController
  layout "tv"

  def show
    @games = Game.all
    @remote_token = SecureRandom.alphanumeric(6).upcase

    remote_url = tv_remote_url(token: @remote_token)
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
