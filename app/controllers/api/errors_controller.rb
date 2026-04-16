module Api
  class ErrorsController < BaseController
    # POST /api/errors
    # Body: { message, stack, game, user_agent, url }
    #
    # Called by public/error-reporter.js whenever an uncaught exception
    # or rejected promise happens in a game page. Best-effort capture:
    # we never return an error body that could itself get reported as
    # an error by the reporter (which would create a crash loop).
    def create
      body = JSON.parse(request.body.read) rescue {}
      report = ErrorReport.record!(
        message:    body["message"],
        stack:      body["stack"],
        game:       body["game"],
        user_agent: body["user_agent"],
        url:        body["url"]
      )

      if report
        render json: { fingerprint: report.fingerprint, occurrences: report.occurrences }, status: :created
      else
        # Silent no-op for blank messages — never surface an error to the reporter.
        render json: { ok: true }, status: :accepted
      end
    end
  end
end
