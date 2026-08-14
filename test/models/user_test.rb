require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is downcased and stripped on save" do
    user = User.create!(email: "  Mixed@Example.COM ", password: "password")
    assert_equal "mixed@example.com", user.email
  end

  test "email uniqueness is case-insensitive" do
    User.create!(email: "dup@example.com", password: "password")
    duplicate = User.new(email: "DUP@example.com", password: "password")
    assert_not duplicate.valid?
    # Neutral message (not the default "has already been taken") to avoid
    # gratuitously confirming a registered address.
    assert_includes duplicate.errors[:email], "can't be used"
  end

  test "password shorter than the minimum is rejected" do
    user = User.new(email: "short@example.com", password: "abc123")
    assert_not user.valid?
    assert_includes user.errors.attribute_names, :password
  end

  test "overly long email is rejected" do
    user = User.new(email: "#{'a' * 256}@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors.attribute_names, :email
  end
end
