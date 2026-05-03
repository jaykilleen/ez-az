module Admin
  class SubmissionsController < ApplicationController
    http_basic_authenticate_with name: "ezaz", password: ENV.fetch("ADMIN_PASSWORD", "ezaz-dev-only")

    def index
      @pending = Submission.pending
      @reviewed = Submission.reviewed.limit(20)
    end

    def show
      @submission = Submission.find(params[:id])
    end

    def preview
      @submission = Submission.find(params[:id])
      response.headers["Content-Security-Policy"] = "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:;"
      render html: @submission.game_html.html_safe, layout: false
    end

    def approve
      submission = Submission.find(params[:id])
      submission.update!(status: "approved", reviewed_at: Time.current, reviewer_notes: params[:notes])
      redirect_to admin_submission_path(submission), notice: "Marked approved. Now copy the HTML to public/games/#{submission.slug}.html, register it in the Game model + Score::GAME_SORT, then deploy."
    end

    def reject
      submission = Submission.find(params[:id])
      submission.update!(status: "rejected", reviewed_at: Time.current, reviewer_notes: params[:notes])
      redirect_to admin_submission_path(submission), notice: "Marked rejected."
    end
  end
end
