module User::Transferable
  # @type instance: User
  extend ActiveSupport::Concern

  TRANSFER_LINK_EXPIRY_DURATION = 4.hours

  module ClassMethods
    # @type instance: singleton(User)
    def find_by_transfer_id(id)
      find_signed(id, purpose: :transfer)
    end
  end

  def transfer_id
    signed_id(purpose: :transfer, expires_in: TRANSFER_LINK_EXPIRY_DURATION)
  end
end
