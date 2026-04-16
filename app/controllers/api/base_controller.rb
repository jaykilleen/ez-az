# Base class for every JSON API controller.
#
# Inheriting from this guarantees that any uncaught exception is returned
# as a JSON body (instead of Rails' default public/500.html) so that the
# client's `fetch(...).then(r => r.json())` never blows up and gets back
# a useful error payload. The alternative — HTML error pages — is exactly
# what caused the generic "Could not reach server" messages on login
# (see issue #16): the client couldn't parse the HTML 500 as JSON, so
# `.catch()` fired with a misleading message.
module Api
  class BaseController < ApplicationController
    # rescue_from matches the LAST-registered handler first, so the
    # generic StandardError fallback goes first and more-specific
    # handlers follow and override it.

    rescue_from StandardError do |e|
      Rails.logger.error("[api] #{e.class}: #{e.message}")
      e.backtrace&.first(10)&.each { |l| Rails.logger.error("  #{l}") }

      message = if Rails.env.production?
        "Something went wrong on our end. Please try again."
      else
        "#{e.class}: #{e.message}"
      end
      render_api_error(:internal_server_error, message, e)
    end

    rescue_from ActionController::ParameterMissing do |e|
      render_api_error(:bad_request, "Missing parameter: #{e.param}", e)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      render_api_error(:unprocessable_entity, e.record.errors.full_messages.first || "Invalid request", e)
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      render_api_error(:not_found, "Not found", e)
    end

    private

    def render_api_error(status, message, exception = nil)
      payload = { error: message }
      if exception && !Rails.env.production?
        payload[:exception] = exception.class.name
        payload[:backtrace] = exception.backtrace&.first(5)
      end
      render json: payload, status: status
    end
  end
end
