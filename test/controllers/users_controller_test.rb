require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get signup_url
    assert_response :success
  end

  test "should create user with valid params" do
    assert_difference('User.count') do
      post users_url, params: { user: { username: "testuser", email: "test@example.com", password: "password123" } }
    end
    assert_redirected_to root_path
  end

  test "should get show" do
    user = users(:one)
    get user_url(user)
    assert_response :success
  end
end
