module Api
  class SubmissionsController < BaseController
    RATE_LIMIT_PER_HOUR = 5
    ALLOWED_UPLOAD_EXTENSIONS = %w[.html .htm].freeze

    def create
      return unless check_rate_limit!
      return unless load_uploaded_html!

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
        :game_html, :kind, :idea_prompt, :contact_email, :notes
      )
    end

    # Kids can upload an .html file directly instead of pasting game_html as
    # a JSON string. The size/extension checks happen here, BEFORE the file
    # is read into memory — an attacker handing us a multi-hundred-MB "game"
    # shouldn't get to make us allocate that much just to find out it's too
    # big. Real content-level defence (dangerous-pattern scan, size-in-bytes
    # cap) still runs in the Submission model once we do read it.
    def load_uploaded_html!
      file = params[:game_file]
      return true unless file.respond_to?(:read) # no file uploaded -- game_html (if any) came as a plain param

      ext = File.extname(file.original_filename.to_s).downcase
      unless ALLOWED_UPLOAD_EXTENSIONS.include?(ext)
        render json: { error: "Uploaded file must be .html or .htm" }, status: :bad_request
        return false
      end

      if file.size > Submission::MAX_HTML_BYTES
        render json: { error: "Uploaded file is too large (#{file.size} bytes, max #{Submission::MAX_HTML_BYTES})" }, status: :bad_request
        return false
      end

      params[:game_html] = file.read
      true
    end

    def check_rate_limit!
      since = 1.hour.ago
      count = Submission.where(submitter_ip: request.remote_ip).where("created_at > ?", since).count
      if count >= RATE_LIMIT_PER_HOUR
        render json: { error: "Rate limit exceeded — max #{RATE_LIMIT_PER_HOUR} submissions per hour. Wait an hour and retry." }, status: :too_many_requests
        return false
      end
      true
    end
  end
end
