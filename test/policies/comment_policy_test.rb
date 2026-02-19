require "test_helper"

class CommentPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @comment = comments(:logo_agreement_jz)
  end

  test "user with card access can view comment" do
    policy = CommentPolicy.new(@comment, user: users(:david), account: @account)
    assert policy.apply(:show?)
  end

  test "user with card access can add comments" do
    card = @comment.card
    policy = CommentPolicy.new(card:, user: users(:david), account: @account)

    assert policy.apply(:create?)
  end

  test "comment creator can update their comment" do
    policy = CommentPolicy.new(@comment, user: users(:jz), account: @account)
    assert policy.apply(:update?)
  end

  test "non-creator cannot update comment" do
    policy = CommentPolicy.new(@comment, user: users(:david), account: @account)
    assert_not policy.apply(:update?)
  end

  test "admin cannot update others comment" do
    policy = CommentPolicy.new(@comment, user: users(:kevin), account: @account)
    assert_not policy.apply(:update?)
  end

  test "comment creator can destroy their comment" do
    policy = CommentPolicy.new(@comment, user: users(:jz), account: @account)
    assert policy.apply(:destroy?)
  end

  test "non-creator cannot destroy comment" do
    policy = CommentPolicy.new(@comment, user: users(:david), account: @account)
    assert_not policy.apply(:destroy?)
  end

  test "edit? is aliased to manage?" do
    policy = CommentPolicy.new(@comment, user: users(:jz), account: @account)
    assert policy.apply(:edit?)
  end
end
