require "test_helper"

class User::RoleTest < ActiveSupport::TestCase
  test "owner is also considered an admin" do
    assert users(:jason).owner?
    assert users(:jason).admin?

    assert users(:kevin).admin?
    assert_not users(:kevin).owner?
  end

  test "owner scope returns only active owners" do
    owners = accounts("37s").users.owner
    assert_includes owners, users(:jason)
    assert_not_includes owners, users(:kevin)
    assert_not_includes owners, users(:david)

    users(:jason).update!(active: false)
    assert_not_includes accounts("37s").users.owner, users(:jason)
  end

  test "admin scope returns active owners and admins" do
    admins = accounts("37s").users.admin
    assert_includes admins, users(:jason)
    assert_includes admins, users(:kevin)
    assert_not_includes admins, users(:david)

    users(:kevin).update!(active: false)
    assert_not_includes accounts("37s").users.admin, users(:kevin)
  end
end
