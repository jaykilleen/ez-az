require "test_helper"

class CountersControllerTest < ActionDispatch::IntegrationTest
  setup do
    Counter.delete_all
  end

  test "counter increments and returns count" do
    get "/counter"
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal 1, data["count"]
  end

  test "counter increments on each request" do
    Counter.create!(key: "visitors", value: 41)
    get "/counter"
    data = JSON.parse(response.body)
    assert_equal 42, data["count"]
  end

  test "counter has no-store cache header" do
    get "/counter"
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
