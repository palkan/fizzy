module Account::Incineratable
  # @type instance: Account
  extend ActiveSupport::Concern

  INCINERATION_GRACE_PERIOD = 30.days

  included do
    # @type self: singleton(Account)
    scope :due_for_incineration, -> { joins(:cancellation).where(account_cancellations: { created_at: ...INCINERATION_GRACE_PERIOD.ago }) }

    define_callbacks :incinerate
  end

  def incinerate
    run_callbacks :incinerate do
      Storage::Entry.suppressing_recording { account.destroy }
    end
  end
end
