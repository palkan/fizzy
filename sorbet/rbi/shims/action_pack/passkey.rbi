# typed: true

# Converted from sig/shims/action_pack/passkey.rbs

class ActionPack::Passkey < ::ApplicationRecord
  sig { params(holder: ::T.untyped, options: ::T.untyped).returns(ActionPack::WebAuthn::PublicKeyCredential::CreationOptions) }
  def self.registration_options(holder:, **options); end

  sig { params(passkey: ::T.untyped, attributes: ::T.untyped).returns(ActionPack::Passkey) }
  def self.register(passkey, **attributes); end

  sig { params(holder: ::T.untyped, options: ::T.untyped).returns(ActionPack::WebAuthn::PublicKeyCredential::RequestOptions) }
  def self.authentication_options(holder: T.unsafe(nil), **options); end

  sig { params(passkey: ::T.untyped).returns(::T.nilable(ActionPack::Passkey)) }
  def self.authenticate(passkey); end

  sig { params(passkey: ::T.untyped).returns(::T.nilable(ActionPack::Passkey)) }
  def authenticate(passkey); end

  sig { returns(ActionPack::WebAuthn::PublicKeyCredential) }
  def to_public_key_credential; end
end

class ActionView::Base
  include ActionPack::Passkey::FormHelper

  sig { params(form_options: ::T::Hash[::T.untyped, ::T.untyped]).returns(String) }
  def form_authenticity_token(form_options: T.unsafe(nil)); end

  sig { params(args: ::T.untyped).returns(String) }
  def passkey_challenge_path(*args); end
end

class ActiveRecord::Base
  sig { params(options: ::T.untyped, blk: ::T.nilable(::T.proc.params(arg0: ActionPack::Passkey::Holder::Config).void)).void }
  def self.has_passkeys(**options, &blk); end
end

