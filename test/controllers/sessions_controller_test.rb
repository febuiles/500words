require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get login_url
    assert_response :success
  end

  test "should create session with valid credentials" do
    user = users(:one)
    post login_url, params: { email: user.email, password: "password" }
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "should get destroy" do
    delete logout_url
    assert_response :redirect
  end
end
