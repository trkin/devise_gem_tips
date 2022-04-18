require "test_helper"

class ApplicationUserControllerTest < ActionDispatch::IntegrationTest
  test "root" do
    get root_path
    assert_response :success
  end

  test "articles non logged in" do
    get articles_path
    assert_response :redirect
  end

  test "articles logged in" do
    sign_in users(:user)
    get articles_path
    assert_response :success
  end
end
