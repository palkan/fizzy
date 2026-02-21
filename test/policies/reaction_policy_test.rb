require "test_helper"

class ReactionPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @reaction = reactions(:kevin)
  end

  test "reacter can manage their own reaction" do
    policy = ReactionPolicy.new(@reaction, user: users(:kevin), account: @account)
    assert policy.apply(:manage?)
  end

  test "other user cannot manage someone else's reaction" do
    policy = ReactionPolicy.new(@reaction, user: users(:david), account: @account)
    assert_not policy.apply(:manage?)
  end

  test "admin cannot manage someone else's reaction" do
    # Kevin's reaction, tested by admin (kevin is admin, but testing with another admin)
    policy = ReactionPolicy.new(reactions(:david), user: users(:kevin), account: @account)
    assert_not policy.apply(:manage?)
  end

  test "viewer cannot create reaction" do
    policy = ReactionPolicy.new(Reaction, user: users(:pat), account: @account)
    assert_not policy.apply(:create?)
  end
end
