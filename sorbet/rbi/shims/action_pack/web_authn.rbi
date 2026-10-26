# typed: true

# Converted from sig/shims/action_pack/web_authn.rbs

module ActionPack::WebAuthn
  module AttestationVerifier
    interface!

    sig { abstract.params(attestation: ActionPack::WebAuthn::Authenticator::Attestation, client_data_json: String).void }
    def verify!(attestation, client_data_json:); end
  end
end
