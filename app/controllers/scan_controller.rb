class ScanController < ApplicationController
  include RespectsStoreHours
  layout "controller"

  def show
    response.headers["Cache-Control"] = "no-store"
  end
end
