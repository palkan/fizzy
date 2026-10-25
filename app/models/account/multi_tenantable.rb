module Account::MultiTenantable
  # @type instance: Account
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Account)
    cattr_accessor :multi_tenant, default: false #: bool
  end

  module ClassMethods
    # @type instance: singleton(Account)
    #: () -> bool
    def accepting_signups?
      multi_tenant || Account.none?
    end
  end
end
