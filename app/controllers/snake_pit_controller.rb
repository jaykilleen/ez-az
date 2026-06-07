class SnakePitController < ApplicationController
  # Phone controller page. The TV Stage is the static file
  # public/games/snake-pit-royale.html (served directly), matching the
  # Dino Jump / Marble Run real-time arcade pattern.
  def join
    render layout: false
  end
end
