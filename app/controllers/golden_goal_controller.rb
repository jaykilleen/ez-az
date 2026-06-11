class GoldenGoalController < ApplicationController
  # Phone controller page. The TV Stage is the static file
  # public/games/golden-goal.html (served directly), matching the
  # Snake Pit / Dino Jump / Marble Run real-time arcade pattern.
  def join
    render layout: false
  end
end
