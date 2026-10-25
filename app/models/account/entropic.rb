module Account::Entropic
  # @type instance: Account
  extend ActiveSupport::Concern

  DEFAULT_ENTROPY_PERIOD = 30.days

  included do
    # @type self: singleton(Account)
    has_one :entropy, as: :container, dependent: :destroy
    after_create -> { create_entropy!(auto_postpone_period: DEFAULT_ENTROPY_PERIOD, account: self) }
  end
end
