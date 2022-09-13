require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_path
    assert_response :success
  end

  test "sign_in_development" do
    get sign_in_development_path users(:user).id
    assert_equal "only_development", response.body
  end
end
