require "rqrcode"

# Renders a QR code SVG for a join URL so the static-file TV games
# (Snake Pit, Dino Jump, Golden Goal, ...) can show a scannable code the same
# way the server-rendered party games do. Static games can't run rqrcode
# inline, so they embed <img src="/qr?url=..."> instead.
#
# Only same-origin (or relative) URLs are encoded, so this can't be abused as
# an open QR generator for arbitrary links.
class QrController < ApplicationController
  MAX_URL = 512

  def show
    url = params[:url].to_s
    return head(:bad_request) if url.blank? || url.length > MAX_URL

    uri = begin
      URI.parse(url)
    rescue URI::InvalidURIError
      nil
    end
    return head(:bad_request) unless uri
    return head(:bad_request) unless uri.host.nil? || uri.host == request.host

    color = params[:color].to_s.gsub(/[^0-9a-fA-F]/, "")
    color = "00ffc8" unless color.length == 6

    svg = RQRCode::QRCode.new(url).as_svg(
      color: color,
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true,
      use_path: true
    )

    expires_in 1.hour, public: true
    send_data svg, type: "image/svg+xml", disposition: "inline"
  end
end
