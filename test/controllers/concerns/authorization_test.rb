require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  test "admins pass the admin check" do
    sign_in_as :kevin

    get board_webhooks_path(boards(:writebook))
    assert_response :success
  end

  test "members are forbidden by the admin check" do
    sign_in_as :jz

    get board_webhooks_path(boards(:writebook))
    assert_response :forbidden
  end

  test "staff pass the staff check" do
    sign_in_as :david

    untenanted { get "/admin/jobs" }
    assert_response :success
  end

  test "non-staff are forbidden by the staff check" do
    sign_in_as :jz

    untenanted { get "/admin/jobs" }
    assert_response :forbidden
  end

  test "active users in active accounts can access the account" do
    sign_in_as :david

    get cards_path
    assert_response :success
  end

  test "visitors aren't checked against an account they're not signed in to" do
    get join_path(code: account_join_codes(:"37s").code)
    assert_response :success
  end

  test "identities without a user in the account are sent to the session menu" do
    sign_in_as :david

    get cards_path(script_name: accounts(:initech).slug)
    assert_redirected_to session_menu_url(script_name: nil)
  end

  test "deactivated users are sent to the session menu outside the account" do
    sign_in_as :david
    users(:david).update!(active: false)

    get cards_path
    assert_redirected_to session_menu_url(script_name: nil)
  end

  test "deactivated users are forbidden from the account's JSON" do
    sign_in_as :david
    users(:david).update!(active: false)

    get cards_path(format: :json)
    assert_response :forbidden
  end

  test "users of a cancelled account are sent to the session menu" do
    sign_in_as :david
    accounts("37s").cancel(initiated_by: users(:jason))

    get cards_path
    assert_redirected_to session_menu_url(script_name: nil)
  end

  test "users of a cancelled account are forbidden from its JSON" do
    sign_in_as :david
    accounts("37s").cancel(initiated_by: users(:jason))

    get cards_path(format: :json)
    assert_response :forbidden
  end
end
