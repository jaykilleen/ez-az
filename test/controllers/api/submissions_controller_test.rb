require "test_helper"
require "tempfile"

class Api::SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup { Submission.delete_all }

  def html_file(content, filename: "game.html")
    file = Tempfile.new([File.basename(filename, ".*"), File.extname(filename)])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/html")
  end

  def base_params(overrides = {})
    {
      kind: "html",
      slug: "up-test-#{SecureRandom.hex(4)}",
      title: "Upload Test",
      creators: "Kid",
      tagline: "Tag",
      score_direction: "desc",
      contact_email: "kid@example.com"
    }.merge(overrides)
  end

  def clean_game_html(extra = "")
    "<html><a href=\"/\">x</a><script>fetch('/api/scores'); #{extra}</script></html>"
  end

  test "creates a pending html submission from JSON game_html" do
    assert_difference -> { Submission.count }, 1 do
      post "/api/submissions", params: base_params(game_html: clean_game_html)
    end
    assert_response :created
    assert_equal "pending", Submission.last.status
    assert_equal "html", Submission.last.kind
  end

  test "creates a pending prompt submission with just an idea" do
    assert_difference -> { Submission.count }, 1 do
      post "/api/submissions", params: {
        kind: "prompt", title: "Idea", creators: "Kid",
        idea_prompt: "A racing game with dinosaurs.",
        contact_email: "kid@example.com"
      }
    end
    assert_response :created
    assert_equal "prompt", Submission.last.kind
    assert_nil Submission.last.slug
  end

  test "prompt submission without idea_prompt is rejected" do
    assert_no_difference -> { Submission.count } do
      post "/api/submissions", params: { kind: "prompt", title: "Idea", creators: "Kid", contact_email: "kid@example.com" }
    end
    assert_response :bad_request
  end

  test "accepts a direct .html file upload and stores its contents as game_html" do
    content = clean_game_html
    assert_difference -> { Submission.count }, 1 do
      post "/api/submissions", params: base_params(game_file: html_file(content))
    end
    assert_response :created
    assert_equal content, Submission.last.game_html
  end

  test "rejects an uploaded file with the wrong extension before reading it" do
    assert_no_difference -> { Submission.count } do
      post "/api/submissions", params: base_params(game_file: html_file("not html", filename: "game.txt"))
    end
    assert_response :bad_request
    assert_match(/\.html or \.htm/, JSON.parse(response.body)["error"])
  end

  test "rejects an uploaded file over the size cap without reading its contents into the submission" do
    huge = "x" * (Submission::MAX_HTML_BYTES + 1)
    assert_no_difference -> { Submission.count } do
      post "/api/submissions", params: base_params(game_file: html_file(huge))
    end
    assert_response :bad_request
    assert_match(/too large/, JSON.parse(response.body)["error"])
  end

  test "rejects uploaded HTML containing a dangerous pattern" do
    dangerous = clean_game_html("document.cookie")
    assert_no_difference -> { Submission.count } do
      post "/api/submissions", params: base_params(game_file: html_file(dangerous))
    end
    assert_response :bad_request
    assert_match(/was rejected/, JSON.parse(response.body)["error"])
  end

  test "rate limits after 5 submissions per hour from the same IP and does not save the 6th" do
    5.times do |i|
      post "/api/submissions", params: base_params(slug: "rate-#{i}-#{SecureRandom.hex(2)}", game_html: clean_game_html)
      assert_response :created
    end
    assert_no_difference -> { Submission.count } do
      post "/api/submissions", params: base_params(slug: "rate-6-#{SecureRandom.hex(2)}", game_html: clean_game_html)
    end
    assert_response :too_many_requests
  end
end
