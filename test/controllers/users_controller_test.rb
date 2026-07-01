require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get signup_url
    assert_response :success
  end

  test "should create user with valid params" do
    assert_difference("User.count") do
      post users_url, params: { user: { username: "testuser", email: "test@example.com", password: "password123" } }
    end
    assert_redirected_to root_path
  end

  test "signup is rate limited after too many attempts" do
    5.times do
      post users_url, params: { user: { username: "", email: "bad", password: "x" } }
      assert_response :unprocessable_entity
    end

    # The 6th attempt within the window is throttled.
    post users_url, params: { user: { username: "", email: "bad", password: "x" } }
    assert_redirected_to signup_path
  end

  test "user can view their own profile" do
    user = users(:one)
    post login_path, params: { email: user.email, password: "password" }
    get user_url(user)
    assert_response :success
  end

  test "user cannot view another users profile" do
    user1 = users(:one)
    user2 = users(:two)
    post login_path, params: { email: user1.email, password: "password" }
    get user_url(user2)
    assert_redirected_to posts_path
  end

  test "unauthenticated user is redirected from profile" do
    user = users(:one)
    get user_url(user)
    assert_response :redirect
  end

  test "user can delete their own account and all its posts" do
    user = users(:one)
    post login_path, params: { email: user.email, password: "password" }

    assert_difference("User.count", -1) do
      assert_difference("Post.count", -user.posts.count) do
        delete user_url(user)
      end
    end

    assert_redirected_to root_path
    assert_nil User.find_by(id: user.id)
  end

  test "deleting an account ends the session" do
    user = users(:one)
    post login_path, params: { email: user.email, password: "password" }
    delete user_url(user)

    # No longer authenticated: a protected page bounces to login.
    get user_url(users(:two))
    assert_redirected_to login_path
  end

  test "unauthenticated user cannot delete an account" do
    user = users(:one)
    assert_no_difference("User.count") do
      delete user_url(user)
    end
    assert_redirected_to login_path
  end
end
