require "test_helper"

class ErrorsDashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    ErrorReport.delete_all
  end

  test "GET /errors renders empty state when there are no reports" do
    get "/errors"
    assert_response :success
    assert_includes response.body, "Errors on EZ-AZ"
    assert_includes response.body, "No errors yet"
  end

  test "GET /errors lists recent reports" do
    ErrorReport.record!(message: "boom", stack: "at foo (x:1)", game: "bloom")
    get "/errors"
    assert_response :success
    assert_includes response.body, "boom"
    assert_includes response.body, "bloom"
    assert_match %r{1x}, response.body
  end

  test "GET /errors sorts newest first" do
    old = ErrorReport.record!(message: "old", stack: "a")
    old.update!(last_seen_at: 1.day.ago)
    ErrorReport.record!(message: "new", stack: "b")

    get "/errors"
    assert response.body.index("new") < response.body.index("old"),
      "newer errors should appear before older ones"
  end

  test "GET /errors displays the total unique-error count" do
    3.times { |i| ErrorReport.record!(message: "err #{i}", stack: "x#{i}") }
    get "/errors"
    assert_match %r{3 unique}, response.body
  end
end
