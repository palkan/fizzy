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

  test "viewer can create comment on triage card" do
    triage_card = cards(:buy_domain)
    assert triage_card.awaiting_triage?, "buy_domain card should be awaiting triage"

    policy = CommentPolicy.new(card: triage_card, user: users(:pat), account: @account)
    assert policy.apply(:create?)
  end

  test "viewer cannot create comment on triaged card" do
    triaged_card = cards(:logo)
    assert triaged_card.triaged?, "logo card should be triaged"

    policy = CommentPolicy.new(card: triaged_card, user: users(:pat), account: @account)
    assert_not policy.apply(:create?)
  end

  test "viewer cannot manage own comment" do
    policy = CommentPolicy.new(@comment, user: users(:pat), account: @account)
    assert_not policy.apply(:manage?)
  end
end
