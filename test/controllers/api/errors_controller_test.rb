require "test_helper"

class Api::ErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ErrorReport.delete_all
  end

  test "POST /api/errors creates an ErrorReport" do
    assert_difference -> { ErrorReport.count }, 1 do
      post "/api/errors",
           params: { message: "boom", stack: "at foo (x:1)", game: "bloom" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :created
    data = JSON.parse(response.body)
    assert data["fingerprint"].present?
    assert_equal 1, data["occurrences"]
  end

  test "identical errors return the same fingerprint with bumped occurrences" do
    post "/api/errors", params: { message: "boom", stack: "at foo (x:1)", game: "bloom" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    first = JSON.parse(response.body)

    post "/api/errors", params: { message: "boom", stack: "at foo (x:1)", game: "bloom" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    second = JSON.parse(response.body)

    assert_equal first["fingerprint"], second["fingerprint"]
    assert_equal 2, second["occurrences"]
    assert_equal 1, ErrorReport.count
  end

  test "blank message returns 202 without creating a report" do
    assert_no_difference -> { ErrorReport.count } do
      post "/api/errors", params: { message: "" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :accepted
  end

  test "invalid JSON body is handled gracefully" do
    assert_no_difference -> { ErrorReport.count } do
      post "/api/errors", params: "not-json",
           headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :accepted
  end
end
