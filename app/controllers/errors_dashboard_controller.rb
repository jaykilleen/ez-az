# Public dashboard at /errors. Renamed from ErrorsController (which
# already exists and handles 404/500 templates) so the two don't
# collide.
class ErrorsDashboardController < ApplicationController
  def index
    @reports = ErrorReport.recent.limit(50)
    @total   = ErrorReport.count
  end
end
