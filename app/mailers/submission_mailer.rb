class SubmissionMailer < ApplicationMailer
  def new_submission(submission)
    @submission = submission
    @admin_url = "https://ez-az.net/admin/submissions/#{submission.id}"
    mail(
      to: "jay@retailtasker.com.au",
      reply_to: submission.contact_email,
      subject: "[EZ-AZ] New submission: #{submission.title} by #{submission.creators}"
    )
  end
end
