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

  test "login is case- and whitespace-insensitive on email" do
    user = users(:one)
    post login_url, params: { email: "  #{user.email.upcase}  ", password: "password" }
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "login fails with wrong password" do
    user = users(:one)
    post login_url, params: { email: user.email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "login fails for unknown email" do
    post login_url, params: { email: "nobody@example.com", password: "password" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "login is rate limited after too many attempts" do
    10.times do
      post login_url, params: { email: "x@example.com", password: "bad" }
      assert_response :unprocessable_entity
    end

    # The 11th attempt within the window is throttled.
    post login_url, params: { email: "x@example.com", password: "bad" }
    assert_redirected_to login_path
  end

  test "should get destroy" do
    delete logout_url
    assert_response :redirect
  end

  test "logout clears authenticated state" do
    user = users(:one)
    post login_url, params: { email: user.email, password: "password" }
    assert_equal user.id, session[:user_id]

    delete logout_url
    assert_nil session[:user_id]

    # Protected resources are no longer reachable after logout.
    get posts_url
    assert_redirected_to login_path
  end

  test "login resets the pre-authentication session (fixation)" do
    # Touch the session as an anonymous visitor so a session exists pre-login.
    get login_url
    pre_login_session = session.id

    user = users(:one)
    post login_url, params: { email: user.email, password: "password" }

    # A successful login must not keep running on the visitor's old session id.
    assert_not_equal pre_login_session, session.id
    assert_equal user.id, session[:user_id]
  end
end
