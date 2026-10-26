# typed: true

# @requires_ancestor: Account
module Account::Entropic
  extend ActiveSupport::Concern

  DEFAULT_ENTROPY_PERIOD = 30.days

  included do
    #: self as singleton(Account)
    has_one :entropy, as: :container, dependent: :destroy
    after_create -> {
      #: self as Account
      create_entropy!(auto_postpone_period: DEFAULT_ENTROPY_PERIOD, account: self)
    }
  end
end
