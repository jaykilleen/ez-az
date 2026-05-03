require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = true
  config.assume_ssl = true
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]
  config.active_support.report_deprecations = false

  # Email via SendGrid SMTP relay (per CLAUDE.md cross-project standard).
  # SENDGRID_API_KEY comes from .kamal/secrets. If absent, emails silently
  # fail and submissions still land in the admin queue.
  if ENV["SENDGRID_API_KEY"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:        "smtp.sendgrid.net",
      port:           587,
      domain:         "ez-az.net",
      user_name:      "apikey",
      password:       ENV["SENDGRID_API_KEY"],
      authentication: :plain,
      enable_starttls_auto: true
    }
    config.action_mailer.default_url_options = { host: "ez-az.net", protocol: "https" }
    config.action_mailer.raise_delivery_errors = false
    config.action_mailer.perform_deliveries  = true
  else
    config.action_mailer.delivery_method = :test
    config.action_mailer.perform_deliveries = false
  end
end
