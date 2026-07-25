class Api::StoreController < ApplicationController
  def status
    response.headers["Cache-Control"] = "no-store"
    render json: StoreHours.status(asked_about)
  end

  private

  # Optional ?at=<iso8601> answers "would the store be open then?" for any
  # moment, so the school-holiday calendar can be verified against production
  # without waiting for the date to arrive. Purely read-only -- it changes the
  # answer, never the store, and nothing keys access off this endpoint.
  # Unparseable input falls back to now rather than erroring.
  def asked_about
    return Time.zone.now if params[:at].blank?
    Time.find_zone(StoreHours::ZONE).parse(params[:at].to_s) || Time.zone.now
  rescue ArgumentError, RangeError
    Time.zone.now
  end
end
