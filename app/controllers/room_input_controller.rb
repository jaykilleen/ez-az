# Serves the TV-side input router JS with the fingerprinted actioncable
# URL baked in at request time. The static game HTML files reference
# this at the stable URL /room-input.js and don't need to know about
# Propshaft asset hashes.
class RoomInputController < ApplicationController
  def show
    response.headers["Content-Type"] = "text/javascript; charset=utf-8"
    response.headers["Cache-Control"] = "no-cache"
    render template: "room_input/show", layout: false, formats: [:js]
  end
end
