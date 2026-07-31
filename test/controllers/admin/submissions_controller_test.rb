require "test_helper"

class Admin::SubmissionsControllerTest < ActionDispatch::IntegrationTest
  def auth_headers
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("ezaz", ENV.fetch("ADMIN_PASSWORD", "ezaz-dev-only")) }
  end

  test "index requires basic auth" do
    get "/admin/submissions"
    assert_response :unauthorized
  end

  test "preview 404s for a prompt-kind submission -- there is no code to preview" do
    submission = Submission.create!(
      kind: "prompt", title: "Idea", creators: "Kid",
      idea_prompt: "A dino racer.", contact_email: "kid@example.com", status: "pending"
    )
    get "/admin/submissions/#{submission.id}/preview", headers: auth_headers
    assert_response :not_found
  end

  test "preview renders the submitted html for an html-kind submission" do
    submission = Submission.create!(
      kind: "html", slug: "preview-test-#{SecureRandom.hex(3)}", title: "T", creators: "Kid",
      tagline: "Tag", score_direction: "desc",
      game_html: "<html><body>hi there</body></html>",
      contact_email: "kid@example.com", status: "pending"
    )
    get "/admin/submissions/#{submission.id}/preview", headers: auth_headers
    assert_response :success
    assert_match "hi there", response.body
  end
end
