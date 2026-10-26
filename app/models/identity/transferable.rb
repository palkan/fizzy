# typed: true

# @requires_ancestor: Identity
module Identity::Transferable
  extend ActiveSupport::Concern

  TRANSFER_LINK_EXPIRY_DURATION = 4.hours

  # @requires_ancestor: singleton(Identity)
  module ClassMethods
    def find_by_transfer_id(id)
      find_signed(id, purpose: :transfer)
    end
  end

  def transfer_id
    signed_id(purpose: :transfer, expires_in: TRANSFER_LINK_EXPIRY_DURATION)
  end
end
