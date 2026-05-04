# Include in any controller whose actions should be gated by store opening
# hours. When the store is shut (and no override is active), requests are
# redirected to /closed.html — same end state as the client-side guard in
# public/opening-hours.js, but the server enforces it so direct URL hits
# (e.g. /games/spotlight) can't slip past.
#
#   class TvController < ApplicationController
#     include RespectsStoreHours
#   end
#
# Skipped automatically in development (matches the localhost exemption in
# the JS) and in test (so existing tests don't have to manage the clock).
# Tests that exercise the guard set RespectsStoreHours.enforce_in_test = true
# in setup and travel_to a closed clock.
module RespectsStoreHours
  extend ActiveSupport::Concern

  # Test-only: when true in the test environment, the guard runs and existing
  # tests would have to manage the clock. Default off so existing tests pass.
  mattr_accessor :enforce_in_test, default: false

  included do
    before_action :enforce_store_hours
  end

  private

  def enforce_store_hours
    return if Rails.env.development?
    return if Rails.env.test? && !RespectsStoreHours.enforce_in_test
    return if StoreHours.open?

    redirect_to "/closed.html", allow_other_host: false
  end
end
