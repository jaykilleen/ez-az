class DescentPartyController < ApplicationController
  # Phone D-pad controller page for Descent Party Mode.
  # The TV Stage is the static file public/games/descent-party.html.
  def join
    render layout: false
  end
end
