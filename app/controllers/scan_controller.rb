class ScanController < ApplicationController
  layout "controller"

  def show
    response.headers["Cache-Control"] = "no-store"
  end
end
