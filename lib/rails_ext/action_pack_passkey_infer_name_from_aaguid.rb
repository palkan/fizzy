# typed: true

# @requires_ancestor: ActionPack::Passkey
module ActionPackPasskeyInferNameFromAaguid
  extend ActiveSupport::Concern

  # @requires_ancestor: singleton(ActionPack::Passkey)
  module ClassMethods
    def register(...)
      super(...).tap do |credential|
        credential.update!(name: credential.authenticator.name) if credential.authenticator && credential.name.blank?
      end
    end
  end

  #: () -> Passkey::Authenticator?
  def authenticator
    Passkey::Authenticator.find_by_aaguid(aaguid)
  end
end
