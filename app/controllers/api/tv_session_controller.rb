require "rqrcode"

class Api::TvSessionController < Api::BaseController
  def show
    response.headers["Cache-Control"] = "no-store"

    token = session[:store_tv_token]
    room  = Room.active.find_by(tv_token: token) if token.present?

    if room.nil?
      room = Room.create_tv_session!
      session[:store_tv_token] = room.tv_token
    end

    version    = EzAz::Version::STRING
    remote_url = tv_remote_url(token: room.tv_token, code: room.code, v: version)

    qr_svg = RQRCode::QRCode.new(remote_url).as_svg(
      color: "00ffc8",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true,
      use_path: true
    )
    qr_svg = qr_svg.sub(/<\?xml[^?]*\?>/, "")
                   .sub(/width="(\d+)" height="(\d+)"/, 'width="100%" height="100%" viewBox="0 0 \1 \2"')

    render json: {
      token:      room.tv_token,
      code:       room.code,
      remote_url: remote_url,
      ac_path:    helpers.asset_path("actioncable.esm.js"),
      qr_svg:     qr_svg
    }
  end
end
