# typed: true

# Converted from sig/shims/passkey.rbs

class Passkey::Authenticator < ::Data
  sig { returns(::T::Array[String]) }
  def aaguids; end

  sig { returns(String) }
  def name; end

  sig { returns(::T.nilable(String)) }
  def icon; end

  sig { params(aaguids: ::T::Array[String], name: String, icon: ::T.nilable(String)).returns(Passkey::Authenticator) }
  def self.new(aaguids:, name:, icon:); end

  sig { params(aaguid: ::T.nilable(String)).returns(::T.nilable(Passkey::Authenticator)) }
  def self.find_by_aaguid(aaguid); end

  sig { returns(::T::Hash[String, Passkey::Authenticator]) }
  def self.registry; end

  sig { returns(::T::Array[Passkey::Authenticator]) }
  def self.all; end
end
