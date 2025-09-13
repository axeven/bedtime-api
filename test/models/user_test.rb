require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should create valid user with name" do
    user = User.new(name: "Test User")
    assert user.valid?
    assert user.save
  end

  test "should require name presence" do
    user = User.new(name: nil)
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should require name not to be empty string" do
    user = User.new(name: "")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should require name not to be only whitespace" do
    user = User.new(name: "   ")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should accept name with minimum length" do
    user = User.new(name: "A")
    assert user.valid?
  end

  test "should accept name with maximum length" do
    user = User.new(name: "A" * 100)
    assert user.valid?
  end

  test "should reject name longer than maximum length" do
    user = User.new(name: "A" * 101)
    assert_not user.valid?
    assert_includes user.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "should save user with valid attributes" do
    user = User.new(name: "Valid User Name")
    assert user.save
    assert_not_nil user.id
    assert_not_nil user.created_at
    assert_not_nil user.updated_at
  end
end
