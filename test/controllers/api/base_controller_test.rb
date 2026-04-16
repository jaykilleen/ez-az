require "test_helper"

# Exercises Api::BaseController's shared behaviour (JSON-for-everything
# error handling). We use a throwaway controller mounted at a private
# test-only route so we can deliberately raise exceptions without
# teaching the real API endpoints tricks they don't need.
class Api::BaseControllerTest < ActionDispatch::IntegrationTest
  # Test-only controller subclasses Api::BaseController and lets each
  # action raise a specific kind of error so we can assert the
  # JSON-ification works end-to-end.
  class ExplodingController < Api::BaseController
    def boom
      raise "kaboom"
    end

    def missing
      raise ActiveRecord::RecordNotFound, "nope"
    end

    def invalid
      # Build an invalid record and use save! so RecordInvalid is raised
      Player.new(username: "").tap { |p| p.save! }
    end
  end

  setup do
    @routes = Rails.application.routes.dup
    @routes.disable_clear_and_finalize = true
    @routes.draw do
      get "/__exploding/boom",    to: "api/base_controller_test/exploding#boom"
      get "/__exploding/missing", to: "api/base_controller_test/exploding#missing"
      get "/__exploding/invalid", to: "api/base_controller_test/exploding#invalid"
    end
    @original_routes = Rails.application.routes
    Rails.application.instance_variable_set(:@routes, @routes)
  end

  teardown do
    Rails.application.instance_variable_set(:@routes, @original_routes)
  end

  test "unhandled exception returns JSON with 500 status" do
    get "/__exploding/boom"
    assert_response :internal_server_error
    assert_includes response.content_type, "application/json"
    body = JSON.parse(response.body)
    assert body.key?("error"),
      "body should include an 'error' key (got #{body.inspect})"
  end

  test "RecordNotFound returns JSON 404" do
    get "/__exploding/missing"
    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Not found", body["error"]
  end

  test "RecordInvalid returns JSON 422 with the validation message" do
    get "/__exploding/invalid"
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["error"].present?,
      "validation message should surface (got #{body.inspect})"
  end

  test "non-production environments include debug info for easier triage" do
    get "/__exploding/boom"
    body = JSON.parse(response.body)
    assert_equal "RuntimeError", body["exception"]
    assert_kind_of Array, body["backtrace"]
  end
end
