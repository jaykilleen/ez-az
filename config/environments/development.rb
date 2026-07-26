require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  # Normally show Rails' debug page locally. The e2e suite sets EZAZ_E2E so the
  # server renders the real error pages instead (config.exceptions_app), which
  # is what production serves and what the 404 spec asserts on.
  config.consider_all_requests_local = ENV["EZAZ_E2E"].blank?
  config.server_timing = true
  config.cache_store = :null_store
end
