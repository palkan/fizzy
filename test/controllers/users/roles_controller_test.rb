require "test_helper"

class Users::RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    assert_not users(:david).admin?

    put user_role_path(users(:david)), params: { user: { role: "admin" } }

    assert_redirected_to account_settings_path
    assert users(:david).reload.admin?
  end

  test "can't promote to special roles" do
    assert_no_changes -> { users(:david).reload.role } do
      put user_role_path(users(:david)), params: { user: { role: "system" } }
    end

    assert_no_changes -> { users(:david).reload.role } do
      put user_role_path(users(:david)), params: { user: { role: "owner" } }
    end
  end

  test "admin cannot demote the owner" do
    assert users(:jason).owner?

    assert_no_changes -> { users(:jason).reload.role } do
      put user_role_path(users(:jason)), params: { user: { role: "admin" } }
    end

    assert_response :forbidden
  end

  test "admin cannot change owner role to member" do
    assert users(:jason).owner?

    assert_no_changes -> { users(:jason).reload.role } do
      put user_role_path(users(:jason)), params: { user: { role: "member" } }
    end

    assert_response :forbidden
  end

  test "admin can set user role to viewer" do
    assert_changes -> { users(:david).reload.role }, from: "member", to: "viewer" do
      put user_role_path(users(:david)), params: { user: { role: "viewer" } }
    end

    assert_redirected_to account_settings_path
  end

  test "admin can promote viewer back to member" do
    assert_changes -> { users(:pat).reload.role }, from: "viewer", to: "member" do
      put user_role_path(users(:pat)), params: { user: { role: "member" } }
    end

    assert_redirected_to account_settings_path
  end
end
