module ActionPackPasskeyInferNameFromAaguid
  # @type instance: ActionPack::Passkey
  extend ActiveSupport::Concern

  module ClassMethods
    # @type instance: singleton(ActionPack::Passkey)
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
