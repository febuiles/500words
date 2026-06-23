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
    assert_response :not_found
  end

  test "owner can edit, update, and destroy their post" do
    post login_path, params: { email: @user1.email, password: "password" }

    get edit_post_path(@post1)
    assert_response :success

    patch post_path(@post1), params: { post: { content: "updated content here" } }
    assert_redirected_to post_path(@post1)
    assert_equal "updated content here", @post1.reload.content

    assert_difference("Post.count", -1) do
      delete post_path(@post1)
    end
  end

  test "user cannot edit, update, or destroy another users post" do
    post login_path, params: { email: @user1.email, password: "password" }

    get edit_post_path(@post2)
    assert_response :not_found

    patch post_path(@post2), params: { post: { content: "hijacked" } }
    assert_response :not_found
    assert_not_equal "hijacked", @post2.reload.content

    assert_no_difference("Post.count") do
      delete post_path(@post2)
    end
    assert_response :not_found
  end

  test "unauthenticated user cannot access any post" do
    get post_path(@post1)
    assert_response :redirect
  end

  test "unauthenticated user is redirected from index" do
    get posts_path
    assert_response :redirect
  end

  test "index only shows the current users own posts" do
    post login_path, params: { email: @user1.email, password: "password" }
    get posts_path
    assert_response :success
    assert_match @post1.content, @response.body
    assert_no_match /Post by #{@user2.username}/, @response.body
  end
end
