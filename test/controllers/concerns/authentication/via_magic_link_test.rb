require "test_helper"

class Authentication::ViaMagicLinkTest < ActionDispatch::IntegrationTest
  test "requesting a code holds the email address in a pending token" do
    untenanted { post session_path, params: { email_address: "david@37signals.com" } }

    assert_redirected_to session_magic_link_url(script_name: nil)
    assert_equal "david@37signals.com", pending_email_address(cookies[:pending_authentication_token])
  end

  test "the pending token is kept from scripts and cross-site requests" do
    untenanted { post session_path, params: { email_address: "david@37signals.com" } }

    assert_match(/; httponly/i, pending_token_cookie)
    assert_match(/; samesite=lax/i, pending_token_cookie)
  end

  test "the pending token expires with its magic link" do
    untenanted { post session_path, params: { email_address: "david@37signals.com" } }

    expires_at = Time.httpdate(pending_token_cookie[/; expires=([^;]+)/i, 1])
    assert_in_delta MagicLink.last.expires_at, expires_at, 1.second
  end

  test "requesting a code over JSON returns the pending token" do
    untenanted { post session_path(format: :json), params: { email_address: "david@37signals.com" } }

    assert_response :created
    assert_equal "david@37signals.com", pending_email_address(response.parsed_body["pending_authentication_token"])
  end

  test "an unknown email address gets the same answer without a magic link" do
    with_multi_tenant_mode(false) do
      assert_no_difference -> { MagicLink.count } do
        untenanted { post session_path, params: { email_address: "nobody@example.com" } }
      end
    end

    assert_redirected_to session_magic_link_url(script_name: nil)
    assert_equal "nobody@example.com", pending_email_address(cookies[:pending_authentication_token])
  end

  test "a code requested on the way somewhere returns there after signing in" do
    account = accounts("37s")
    identity = identities(:mike)

    post join_path(code: account_join_codes(:"37s").code, script_name: account.slug), params: { email_address: identity.email_address }
    assert_redirected_to session_magic_link_url(script_name: nil)
    follow_redirect!

    untenanted { post session_magic_link_url, params: { code: identity.magic_links.order(id: :desc).first.code } }
    assert_redirected_to new_users_verification_url(script_name: account.slug)
  end

  test "a code requested on the way to nowhere keeps the page to return to" do
    get cards_path
    follow_redirect!

    sign_in_as :david
    assert_redirected_to cards_url
  end

  test "signing in forgets the pending token" do
    sign_in_as :david
    assert_empty cookies[:pending_authentication_token].to_s
  end

  test "magic link codes aren't shown outside development" do
    untenanted { post session_path, params: { email_address: "david@37signals.com" } }

    assert_nil response.headers["X-Magic-Link-Code"]
    assert_nil flash[:magic_link_code]
  end

  test "magic link codes are shown in development" do
    Rails.env.stubs(:development?).returns(true)

    untenanted { post session_path, params: { email_address: "david@37signals.com" } }

    assert_equal MagicLink.last.code, response.headers["X-Magic-Link-Code"]
    assert_equal MagicLink.last.code, flash[:magic_link_code]
  end

  test "an unknown email address is shown a code of the usual length in development" do
    Rails.env.stubs(:development?).returns(true)

    with_multi_tenant_mode(false) do
      untenanted { post session_path, params: { email_address: "nobody@example.com" } }
    end

    assert_match(/\A[0-9A-Z]{6}\z/, response.headers["X-Magic-Link-Code"])
  end

  test "a code that reaches the flash outside development is refused" do
    Rails.env.stubs(:development?).returns(true).then.returns(false)

    error = assert_raises(RuntimeError) do
      untenanted { post session_path, params: { email_address: "david@37signals.com" } }
    end
    assert_equal "Leaking magic link via flash in test?", error.message
  end

  private
    def pending_email_address(token)
      Rails.application.message_verifier(:pending_authentication).verified(token)
    end

    def pending_token_cookie
      Array(response.headers["Set-Cookie"]).find { it.start_with?("pending_authentication_token=") }
    end
end
