require "rqrcode"

class TvController < ApplicationController
  layout "tv"

  def show
    @games = Game.all
    @qr_code_svg = RQRCode::QRCode.new("https://ez-az.net").as_svg(
      color: "00ffc8",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true,
      use_path: true
    ).html_safe
  end
end
