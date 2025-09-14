require "test_helper"

class Api::V1::RoutingTest < ActionDispatch::IntegrationTest
  test "API v1 users POST route is configured" do
    assert_routing({ method: "post", path: "/api/v1/users" },
                  { controller: "api/v1/users", action: "create" })
  end

  test "health check route exists" do
    assert_routing "/up", { controller: "rails/health", action: "show" }
  end

  test "API namespace is properly configured" do
    # Verify the route exists in the routing table
    routes = Rails.application.routes.routes
    api_route = routes.find { |r| r.path.spec.to_s.include?("/api/v1/users") }

    assert api_route, "API v1 users route should exist"
    assert_equal "POST", api_route.verb
  end

  test "only POST method is allowed for users endpoint" do
    # This test verifies that only POST is configured, other methods will return 404
    routes = Rails.application.routes.routes
    users_routes = routes.select { |r| r.path.spec.to_s.include?("/api/v1/users") }

    assert_equal 1, users_routes.length, "Should only have one route for /api/v1/users"
    assert_equal "POST", users_routes.first.verb
  end
end
