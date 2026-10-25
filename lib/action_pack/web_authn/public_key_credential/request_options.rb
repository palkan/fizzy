# = Action Pack WebAuthn Public Key Credential Request Options
#
# Generates options for the WebAuthn authentication ceremony (using an existing
# credential). These options are passed to +navigator.credentials.get()+ in
# the browser to prompt the user to authenticate with a registered authenticator.
#
# == Usage
#
#   options = ActionPack::WebAuthn::PublicKeyCredential::RequestOptions.new(
#     credentials: current_user.webauthn_credentials
#   )
#
#   # In your controller, return as JSON for the JavaScript WebAuthn API
#   render json: { publicKey: options.as_json }
#
# == Attributes
#
# [+credentials+]
#   A collection of credential records for the user. Each credential must
#   respond to +id+ returning the Base64URL-encoded credential ID, and
#   +transports+ returning an array of transport strings.
#
# [+relying_party+]
#   The relying party (your application) configuration. Defaults to
#   +ActionPack::WebAuthn.relying_party+.
class ActionPack::WebAuthn::PublicKeyCredential::RequestOptions < ActionPack::WebAuthn::PublicKeyCredential::Options
  attribute :credentials, default: -> { [] } #: Array[ActionPack::WebAuthn::PublicKeyCredential]
  attribute :challenge_expiration, default: -> { Rails.configuration.action_pack.web_authn.request_challenge_expiration } #: ActiveSupport::Duration?
  attribute :challenge_purpose, default: "authentication" #: String?

  #: (?Hash[Symbol, untyped]) -> void
  def initialize(attributes = {})
    super
    validate!
  end

  # Returns a Hash suitable for JSON serialization and passing to the
  # WebAuthn JavaScript API.
  #: (?Hash[Symbol, untyped]?) -> Hash[String, untyped]
  def as_json(options = {})
    json = {
      challenge: challenge,
      rpId: relying_party.id,
      allowCredentials: credentials.map { |credential| allow_credential_json(credential) },
      userVerification: user_verification.to_s
    }

    json.as_json(options)
  end

  private
    #: (ActionPack::WebAuthn::PublicKeyCredential) -> Hash[Symbol, untyped]
    def allow_credential_json(credential)
      hash = { type: "public-key", id: credential.id } #: Hash[Symbol, untyped]
      hash[:transports] = credential.transports if credential.transports.any?
      hash
    end
end
