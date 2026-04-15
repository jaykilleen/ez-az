require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "propshaft"

require_relative "../lib/middleware/static_cache_headers"

module EzAz
  class Application < Rails::Application
    config.load_defaults 8.0

    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { SecureRandom.hex(64) }

    # Serve static files from public/ (no Nginx in front of Puma)
    config.public_file_server.enabled = true

    # Custom cache headers for static files (HTML: no-cache, assets: 1h)
    config.middleware.insert_before ActionDispatch::Static, StaticCacheHeaders

    # Use custom 404 page in all environments
    config.exceptions_app = routes

    # Disable unused features
    config.autoload_lib(ignore: %w[middleware])
  end
end
