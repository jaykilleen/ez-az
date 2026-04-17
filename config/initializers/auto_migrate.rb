# Run any pending migrations automatically on boot in production.
#
# Hatchbox doesn't run db:migrate by default. Without this, any deploy that
# adds migrations would leave the production database in an inconsistent state
# and cause 500 errors on every DB-touching endpoint.
if Rails.env.production?
  begin
    ActiveRecord::Tasks::DatabaseTasks.create_current
    ActiveRecord::Tasks::DatabaseTasks.migrate
    ActiveRecord::Base.clear_all_connections!
  rescue => e
    Rails.logger.error("[auto_migrate] #{e.class}: #{e.message}")
    e.backtrace&.first(5)&.each { |l| Rails.logger.error("  #{l}") }
  end
end
