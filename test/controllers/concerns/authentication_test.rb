require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "requests outside an account are sent to the session menu" do
    sign_in_as :david

    untenanted { get cards_path }
    assert_redirected_to session_menu_url(script_name: nil)
  end

  test "unauthenticated requests are sent to sign in and return afterwards" do
    get cards_path
    assert_redirected_to new_session_url(script_name: nil)
    follow_redirect!

    sign_in_as :david
    assert_redirected_to cards_url
  end

  test "signing in without a page to return to lands on the account's landing page" do
    sign_in_as :david
    assert_redirected_to landing_url(script_name: nil)
  end

  test "unauthenticated requests outside an account aren't returned to" do
    untenanted { get "/admin/jobs" }
    assert_redirected_to new_session_url(script_name: nil)
    follow_redirect!

    sign_in_as :david
    assert_redirected_to landing_url(script_name: nil)
  end

  test "signing in records where the session comes from" do
    identity = identities(:david)
    identity.send_magic_link
    magic_link = identity.magic_links.order(id: :desc).first

    untenanted do
      post session_path, params: { email_address: identity.email_address }
      post session_magic_link_url, params: { code: magic_link.code }, headers: { "User-Agent" => "Fizzy Test Browser" }
    end

    session = identity.sessions.last
    assert_equal "Fizzy Test Browser", session.user_agent
    assert_equal "127.0.0.1", session.ip_address
  end

  test "the session cookie resumes the session on later requests" do
    sign_in_as :david

    get cards_path
    assert_response :success
  end

  test "the session cookie is kept from scripts and cross-site requests" do
    sign_in_as :david

    assert_match(/; httponly/i, session_cookie)
    assert_match(/; samesite=lax/i, session_cookie)
  end

  test "the session cookie outlives the browser session" do
    sign_in_as :david

    expires_at = Time.httpdate(session_cookie[/; expires=([^;]+)/i, 1])
    assert expires_at > 1.year.from_now
  end

  test "a bearer token authenticates JSON requests" do
    get cards_path(format: :json), headers: bearer_token(:davids_api_token)
    assert_response :success
  end

  test "a read-only bearer token authenticates reads" do
    get cards_path(format: :json), headers: bearer_token(:jasons_api_token)
    assert_response :success
  end

  test "a bearer token doesn't authenticate HTML requests" do
    get cards_path, headers: bearer_token(:davids_api_token)
    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get cards_path(format: :json), headers: { "HTTP_AUTHORIZATION" => "Bearer unknown" }
    assert_response :unauthorized
  end

  test "a read-only bearer token is refused for writes" do
    post boards_path(format: :json), params: { board: { name: "Read only" } }, headers: bearer_token(:jasons_api_token)
    assert_response :unauthorized
  end

  test "signed-in identities are sent away from signing in" do
    sign_in_as :david

    untenanted { get new_session_path }
    assert_redirected_to root_url(script_name: nil)
  end

  test "account-free pages are left when requested inside an account" do
    get new_session_path
    assert_redirected_to root_url
  end

  test "signing out ends the session and forgets its cookie" do
    sign_in_as :david

    assert_difference -> { Session.count }, -1 do
      untenanted { delete session_path }
    end
    assert_empty cookies[:session_token].to_s

    get cards_path
    assert_redirected_to new_session_url(script_name: nil)
  end

  private
    def session_cookie
      Array(response.headers["Set-Cookie"]).find { it.start_with?("session_token=") }
    end

    def bearer_token(name)
      { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(name).token}" }
    end
end
