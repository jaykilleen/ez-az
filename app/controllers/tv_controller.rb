require "rqrcode"

class TvController < ApplicationController
  layout "tv"

  def show
    @games = Game.all
    svg = RQRCode::QRCode.new("https://ez-az.net").as_svg(
      color: "00ffc8",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true,
      use_path: true
    )
    # Strip XML declaration, add viewBox so it scales with CSS
    svg = svg.sub(/<\?xml[^?]*\?>/, "")
             .sub(/width="(\d+)" height="(\d+)"/, 'width="100%" height="100%" viewBox="0 0 \1 \2"')
    @qr_code_svg = svg.html_safe
  end
end
