class ManifestController < ApplicationController
  def show
    response.headers["Cache-Control"] = "no-cache"
    render json: {
      name:             "EZ-AZ",
      short_name:       "EZ-AZ",
      description:      "The family video game store",
      start_url:        "/",
      display:          "fullscreen",
      background_color: "#0a0a12",
      theme_color:      "#00ffc8",
      icons: [
        { src: helpers.asset_path("icons/az-192.png"), sizes: "192x192", type: "image/png", purpose: "any" },
        { src: helpers.asset_path("icons/az-512.png"), sizes: "512x512", type: "image/png", purpose: "any" },
        { src: helpers.asset_path("icons/az-192.png"), sizes: "192x192", type: "image/png", purpose: "maskable" },
        { src: helpers.asset_path("icons/az-512.png"), sizes: "512x512", type: "image/png", purpose: "maskable" }
      ]
    }
  end
end
