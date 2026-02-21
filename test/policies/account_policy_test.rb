require "test_helper"

class AccountPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
  end

  test "owner can update account" do
    policy = AccountPolicy.new(@account, user: users(:jason), account: @account)
    assert policy.apply(:update?)
  end

  test "admin can update account" do
    policy = AccountPolicy.new(@account, user: users(:kevin), account: @account)
    assert policy.apply(:update?)
  end

  test "member cannot update account" do
    policy = AccountPolicy.new(@account, user: users(:david), account: @account)
    assert_not policy.apply(:update?)
  end

  test "only owner can destroy account" do
    policy = AccountPolicy.new(@account, user: users(:jason), account: @account)
    assert policy.apply(:destroy?)
  end

  test "admin cannot destroy account" do
    policy = AccountPolicy.new(@account, user: users(:kevin), account: @account)
    assert_not policy.apply(:destroy?)
  end

  test "member cannot destroy account" do
    policy = AccountPolicy.new(@account, user: users(:david), account: @account)
    assert_not policy.apply(:destroy?)
  end

  # manage? covers: account settings, join codes, entropy, exports
  test "admin can manage account" do
    policy = AccountPolicy.new(@account, user: users(:kevin), account: @account)
    assert policy.apply(:manage?)
  end

  test "owner can manage account" do
    policy = AccountPolicy.new(@account, user: users(:jason), account: @account)
    assert policy.apply(:manage?)
  end

  test "member cannot manage account" do
    policy = AccountPolicy.new(@account, user: users(:david), account: @account)
    assert_not policy.apply(:manage?)
  end

  test "admin can manage billing" do
    policy = AccountPolicy.new(@account, user: users(:kevin), account: @account)
    assert policy.apply(:manage_billing?)
  end

  test "member cannot manage billing" do
    policy = AccountPolicy.new(@account, user: users(:david), account: @account)
    assert_not policy.apply(:manage_billing?)
  end

  test "viewer cannot manage account" do
    policy = AccountPolicy.new(@account, user: users(:pat), account: @account)
    assert_not policy.apply(:manage?)
  end

  test "viewer cannot update account" do
    policy = AccountPolicy.new(@account, user: users(:pat), account: @account)
    assert_not policy.apply(:update?)
  end

  test "viewer cannot destroy account" do
    policy = AccountPolicy.new(@account, user: users(:pat), account: @account)
    assert_not policy.apply(:destroy?)
  end
end
