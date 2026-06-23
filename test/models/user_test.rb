require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is downcased and stripped on save" do
    user = User.create!(email: "  Mixed@Example.COM ", username: "mixed", password: "password")
    assert_equal "mixed@example.com", user.email
  end

  test "username surrounding whitespace is stripped" do
    user = User.create!(email: "ws@example.com", username: "  spacey  ", password: "password")
    assert_equal "spacey", user.username
  end

  test "email uniqueness is case-insensitive" do
    User.create!(email: "dup@example.com", username: "dup1", password: "password")
    duplicate = User.new(email: "DUP@example.com", username: "dup2", password: "password")
    assert_not duplicate.valid?
    # Neutral message (not the default "has already been taken") to avoid
    # gratuitously confirming a registered address.
    assert_includes duplicate.errors[:email], "can't be used"
  end

  test "password shorter than the minimum is rejected" do
    user = User.new(email: "short@example.com", username: "shortpw", password: "abc123")
    assert_not user.valid?
    assert_includes user.errors.attribute_names, :password
  end

  test "overly long email and username are rejected" do
    user = User.new(email: "#{'a' * 256}@example.com", username: "a" * 31, password: "password")
    assert_not user.valid?
    assert_includes user.errors.attribute_names, :email
    assert_includes user.errors.attribute_names, :username
  end
end
