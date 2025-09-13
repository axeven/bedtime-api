require "test_helper"

class Api::V1::BaseControllerTest < ActiveSupport::TestCase
  # We'll test the base controller functionality using unit tests instead of integration tests
  # since we don't have actual endpoints yet
  
  setup do
    @controller = Api::V1::BaseController.new
    @controller.define_singleton_method(:render) do |options|
      @render_options = options
    end
    @controller.instance_variable_set(:@render_options, {})
    
    # Mock Rails.logger to avoid actual logging during tests
    @original_logger = Rails.logger
    Rails.logger = Logger.new(StringIO.new)
  end

  teardown do
    Rails.logger = @original_logger
  end

  test "handle_standard_error renders proper JSON response" do
    exception = StandardError.new("Test error")
    
    @controller.send(:handle_standard_error, exception)
    render_options = @controller.instance_variable_get(:@render_options)
    
    assert_equal :internal_server_error, render_options[:status]
    assert_equal "Internal server error", render_options[:json][:error]
    assert_equal "INTERNAL_ERROR", render_options[:json][:error_code]
  end

  test "handle_not_found renders proper JSON response" do
    exception = ActiveRecord::RecordNotFound.new("Test not found")
    
    @controller.send(:handle_not_found, exception)
    render_options = @controller.instance_variable_get(:@render_options)
    
    assert_equal :not_found, render_options[:status]
    assert_equal "Resource not found", render_options[:json][:error]
    assert_equal "NOT_FOUND", render_options[:json][:error_code]
  end

  test "handle_bad_request renders proper JSON response" do
    exception = ActionController::ParameterMissing.new("test_param")
    
    @controller.send(:handle_bad_request, exception)
    render_options = @controller.instance_variable_get(:@render_options)
    
    assert_equal :bad_request, render_options[:status]
    assert_equal "param is missing or the value is empty or invalid: test_param", render_options[:json][:error]
    assert_equal "BAD_REQUEST", render_options[:json][:error_code]
  end

  test "handle_validation_error renders proper JSON response" do
    user = User.new(name: "")
    user.validate
    exception = ActiveRecord::RecordInvalid.new(user)
    
    @controller.send(:handle_validation_error, exception)
    render_options = @controller.instance_variable_get(:@render_options)
    
    assert_equal :unprocessable_entity, render_options[:status]
    assert_equal "Validation failed", render_options[:json][:error]
    assert_equal "VALIDATION_ERROR", render_options[:json][:error_code]
    assert render_options[:json][:details].present?
  end

  test "render_success returns proper JSON response" do
    @controller.send(:render_success, { message: "Success" }, :created)
    render_options = @controller.instance_variable_get(:@render_options)
    
    assert_equal :created, render_options[:status]
    assert_equal "Success", render_options[:json][:message]
  end

  test "render_error returns proper JSON response" do
    @controller.send(:render_error, "Test error", "TEST_ERROR", { field: "value" }, :bad_request)
    render_options = @controller.instance_variable_get(:@render_options)
    
    assert_equal :bad_request, render_options[:status]
    assert_equal "Test error", render_options[:json][:error]
    assert_equal "TEST_ERROR", render_options[:json][:error_code]
    assert_equal "value", render_options[:json][:details][:field]
  end

  test "render_validation_error returns proper JSON response" do
    user = User.new(name: "")
    user.validate
    
    @controller.send(:render_validation_error, user)
    render_options = @controller.instance_variable_get(:@render_options)
    
    assert_equal :unprocessable_entity, render_options[:status]
    assert_equal "Validation failed", render_options[:json][:error]
    assert_equal "VALIDATION_ERROR", render_options[:json][:error_code]
    assert render_options[:json][:details].present?
  end
end