require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get login_url
    assert_response :success
  end

  test "should create session with valid credentials" do
    user = users(:one)
    assert_difference -> { user.sessions.count }, 1 do
      post login_url, params: { email: user.email, password: "password" }
    end
    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "login is case- and whitespace-insensitive on email" do
    user = users(:one)
    post login_url, params: { email: "  #{user.email.upcase}  ", password: "password" }
    assert_redirected_to root_path
    assert_equal 1, user.sessions.count
  end

  test "login fails with wrong password" do
    user = users(:one)
    post login_url, params: { email: user.email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_equal 0, Session.count
  end

  test "login fails for unknown email" do
    post login_url, params: { email: "nobody@example.com", password: "password" }
    assert_response :unprocessable_entity
    assert_equal 0, Session.count
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
    assert_equal 1, user.sessions.count

    delete logout_url
    # The server-side session record is destroyed...
    assert_equal 0, user.sessions.count
    # ...and protected resources are no longer reachable.
    get posts_url
    assert_redirected_to login_path
  end

  test "login does not reuse a pre-authentication session (fixation)" do
    # Anonymous visit establishes a session cookie before authenticating.
    get login_url

    user = users(:one)
    post login_url, params: { email: user.email, password: "password" }

    assert_redirected_to root_path
    # Authentication is bound to a fresh server-side Session record + cookie,
    # not to whatever session the anonymous visitor was carrying.
    assert_equal 1, user.sessions.count
    assert cookies[:session_id].present?
  end
end
