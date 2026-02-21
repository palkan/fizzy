require "test_helper"

class WebhookPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
    @webhook = webhooks(:active)
  end

  test "board admin can view webhook" do
    policy = WebhookPolicy.new(@webhook, user: users(:david), account: @account)
    assert policy.apply(:show?)
  end

  test "non-admin cannot view webhook" do
    policy = WebhookPolicy.new(@webhook, user: users(:jz), account: @account)
    assert_not policy.apply(:show?)
  end

  test "board admin can create webhooks" do
    policy = WebhookPolicy.new(board: @board, user: users(:david), account: @account)
    assert policy.apply(:create?)
  end

  test "non-admin cannot create webhooks" do
    policy = WebhookPolicy.new(board: @board, user: users(:jz), account: @account)
    assert_not policy.apply(:create?)
  end

  test "board admin can update webhook" do
    policy = WebhookPolicy.new(@webhook, user: users(:david), account: @account)
    assert policy.apply(:update?)
  end

  test "board admin can destroy webhook" do
    policy = WebhookPolicy.new(@webhook, user: users(:david), account: @account)
    assert policy.apply(:destroy?)
  end

  test "account admin can manage any webhook" do
    policy = WebhookPolicy.new(@webhook, user: users(:kevin), account: @account)

    assert policy.apply(:show?)
    assert policy.apply(:update?)
    assert policy.apply(:destroy?)
  end

  test "account admin can create webhooks for any board" do
    policy = WebhookPolicy.new(board: @board, user: users(:kevin), account: @account)
    assert policy.apply(:create?)
  end

  test "viewer cannot view webhooks" do
    policy = WebhookPolicy.new(@webhook, user: users(:pat), account: @account)
    assert_not policy.apply(:show?)
  end

  test "viewer cannot create webhooks" do
    policy = WebhookPolicy.new(board: @board, user: users(:pat), account: @account)
    assert_not policy.apply(:create?)
  end

  test "viewer cannot manage webhooks" do
    policy = WebhookPolicy.new(@webhook, user: users(:pat), account: @account)
    assert_not policy.apply(:manage?)
  end
end
