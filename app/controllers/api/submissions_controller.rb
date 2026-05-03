module Api
  class SubmissionsController < BaseController
    RATE_LIMIT_PER_HOUR = 5

    def create
      check_rate_limit!

      attrs = submission_params.merge(submitter_ip: request.remote_ip, status: "pending")
      submission = Submission.new(attrs)

      if submission.save
        SubmissionMailer.new_submission(submission).deliver_later rescue nil
        render json: {
          id: submission.id,
          slug: submission.slug,
          status: submission.status,
          message: "Submission received! Jay reviews submissions personally and will email #{submission.contact_email} either way."
        }, status: :created
      else
        render json: { error: submission.errors.full_messages.first || "Invalid submission" }, status: :bad_request
      end
    end

    private

    def submission_params
      params.permit(
        :slug, :title, :creators, :tagline, :score_direction, :is_chill,
        :game_html, :contact_email, :notes
      )
    end

    def check_rate_limit!
      since = 1.hour.ago
      count = Submission.where(submitter_ip: request.remote_ip).where("created_at > ?", since).count
      if count >= RATE_LIMIT_PER_HOUR
        render json: { error: "Rate limit exceeded — max #{RATE_LIMIT_PER_HOUR} submissions per hour. Wait an hour and retry." }, status: :too_many_requests
        return
      end
    end
  end
end
