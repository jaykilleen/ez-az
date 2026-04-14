class CountersController < ApplicationController
  def show
    count = Counter.increment_and_get("visitors")
    response.headers["Cache-Control"] = "no-store"
    render json: { count: count }
  end
end
