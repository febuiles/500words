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
end
