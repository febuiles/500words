require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "content within the limit is valid" do
    post = Post.new(content: "a few words here", user: users(:one))
    assert post.valid?
  end

  test "content over the maximum length is rejected" do
    post = Post.new(content: "a" * (Post::MAX_CONTENT_LENGTH + 1), user: users(:one))
    assert_not post.valid?
    assert_includes post.errors.attribute_names, :content
  end

  test "blank content is rejected" do
    post = Post.new(content: "", user: users(:one))
    assert_not post.valid?
  end

  test "word count is calculated on save" do
    post = Post.create!(content: "one two three four five", user: users(:one))
    assert_equal 5, post.word_count
  end

  test "posts are numbered sequentially per user" do
    second = Post.create!(content: "words", user: users(:one))
    third = Post.create!(content: "words", user: users(:one))
    other = Post.create!(content: "words", user: users(:two))

    assert_equal 2, second.number
    assert_equal 3, third.number
    assert_equal 2, other.number
  end

  test "numbers are not reused for the user's earlier posts after a deletion in the middle" do
    second = Post.create!(content: "words", user: users(:one))
    posts(:one).destroy
    third = Post.create!(content: "words", user: users(:one))

    assert_equal 3, third.number
    assert_equal 2, second.reload.number
  end

  test "display_title falls back to the post number" do
    post = Post.create!(content: "words", user: users(:one))
    assert_equal "Post 2", post.display_title

    post.update!(title: "Morning pages")
    assert_equal "Morning pages", post.display_title
  end

  test "a blank title reverts to the default name" do
    post = Post.create!(content: "words", user: users(:one), title: "Named")
    post.update!(title: "   ")
    assert_nil post.title
    assert_equal "Post 2", post.display_title
  end

  test "title over the maximum length is rejected" do
    post = Post.new(content: "words", user: users(:one), title: "a" * (Post::MAX_TITLE_LENGTH + 1))
    assert_not post.valid?
    assert_includes post.errors.attribute_names, :title
  end
end
