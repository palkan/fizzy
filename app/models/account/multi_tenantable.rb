# typed: true

# @requires_ancestor: Account
module Account::MultiTenantable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Account)
    cattr_accessor :multi_tenant, default: false #: bool
  end

  # @requires_ancestor: singleton(Account)
  module ClassMethods
    #: () -> bool
    def accepting_signups?
      multi_tenant || Account.none?
    end
  end
end
