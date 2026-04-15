# Legacy redirect for static HTML that still references /icons/az-192.png
# and /icons/az-512.png. Sends the browser to the fingerprinted, immutable
# asset URL served by Propshaft. Once everything pulls from
# /manifest.json (which already points at fingerprinted paths), this
# controller can go away.
class IconsController < ApplicationController
  ALLOWED = %w[az-192.png az-512.png].freeze

  def show
    filename = "#{params[:name]}.#{params[:format]}"
    raise ActionController::RoutingError, "Not Found" unless ALLOWED.include?(filename)

    redirect_to helpers.asset_path("icons/#{filename}"),
                status: :moved_permanently,
                allow_other_host: false
  end
end
