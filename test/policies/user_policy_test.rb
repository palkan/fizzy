require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
  end

  test "admin can change non-owner user" do
    admin = users(:kevin)
    target = users(:jz)
    policy = UserPolicy.new(target, user: admin, account: @account)

    assert policy.apply(:update?)
  end

  test "admin cannot change owner" do
    admin = users(:kevin)
    owner = users(:jason)
    policy = UserPolicy.new(owner, user: admin, account: @account)

    assert_not policy.apply(:update?)
  end

  test "user can change self" do
    user = users(:jz)
    policy = UserPolicy.new(user, user: user, account: @account)

    assert policy.apply(:update?)
  end

  test "non-admin cannot change others" do
    user = users(:jz)
    other = users(:david)
    policy = UserPolicy.new(other, user: user, account: @account)

    assert_not policy.apply(:update?)
  end

  test "owner can change admin" do
    owner = users(:jason)
    admin = users(:kevin)
    policy = UserPolicy.new(admin, user: owner, account: @account)

    assert policy.apply(:update?)
  end

  test "admin can destroy non-owner" do
    admin = users(:kevin)
    target = users(:jz)
    policy = UserPolicy.new(target, user: admin, account: @account)

    assert policy.apply(:destroy?)
  end

  test "admin cannot destroy owner" do
    admin = users(:kevin)
    owner = users(:jason)
    policy = UserPolicy.new(owner, user: admin, account: @account)

    assert_not policy.apply(:destroy?)
  end

  test "admin can administer non-owner non-self" do
    admin = users(:kevin)
    target = users(:jz)
    policy = UserPolicy.new(target, user: admin, account: @account)

    assert policy.apply(:change_role?)
  end

  test "admin cannot administer owner" do
    admin = users(:kevin)
    owner = users(:jason)
    policy = UserPolicy.new(owner, user: admin, account: @account)

    assert_not policy.apply(:change_role?)
  end

  test "admin cannot administer self" do
    admin = users(:kevin)
    policy = UserPolicy.new(admin, user: admin, account: @account)

    assert_not policy.apply(:change_role?)
  end

  test "non-admin cannot administer others" do
    user = users(:jz)
    other = users(:david)
    policy = UserPolicy.new(other, user: user, account: @account)

    assert_not policy.apply(:change_role?)
  end

  test "user can see users in same account" do
    user = users(:jz)
    other = users(:david)
    policy = UserPolicy.new(other, user: user, account: @account)

    assert policy.apply(:show?)
  end

  test "edit? is aliased to update?" do
    user = users(:jz)
    policy = UserPolicy.new(user, user: user, account: @account)

    assert policy.apply(:edit?)
  end

  test "viewer excluded from assignable scope" do
    scoped = UserPolicy.new(User, user: users(:david), account: @account)
      .apply_scope(User.all, type: :active_record_relation, name: :assignable)

    assert_not_includes scoped, users(:pat)
    assert_not_includes scoped, users(:system)
    assert_includes scoped, users(:david)
  end

  test "relation scope returns account users" do
    user = users(:david)
    scoped = UserPolicy.new(User, user: user, account: @account)
      .apply_scope(User.all, type: :active_record_relation)

    assert_includes scoped, users(:david)
    assert_includes scoped, users(:kevin)
    assert_not_includes scoped, users(:mike) # from initech account
  end
end
