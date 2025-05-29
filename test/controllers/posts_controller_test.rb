require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user1 = users(:one)
    @user2 = users(:two)
    @post1 = posts(:one)
    @post2 = posts(:two)
  end

  test "user can access their own post" do
    post login_path, params: { email: @user1.email, password: "password" }
    get post_path(@post1)
    assert_response :success
  end

  test "user cannot access other users posts" do
    post login_path, params: { email: @user1.email, password: "password" }
    get post_path(@post2)
    assert_response :unauthorized
  end

  test "unauthenticated user cannot access any post" do
    get post_path(@post1)
    assert_response :redirect
  end

  test "should get index without authentication" do
    get posts_path
    assert_response :success
  end
end
