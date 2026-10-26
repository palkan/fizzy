# typed: true

# @requires_ancestor: Account
module Account::Cancellable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Account)
    has_one :cancellation, dependent: :destroy

    define_callbacks :cancel
    define_callbacks :reactivate
  end

  #: (?initiated_by: User?) -> void
  def cancel(initiated_by: Current.user)
    with_lock do
      if cancellable? && active?
        run_callbacks :cancel do
          create_cancellation!(initiated_by: initiated_by)
        end

        cancellation = self.cancellation #: as !nil
        AccountMailer.cancellation(cancellation).deliver_later
      end
    end
  end

  #: () -> void
  def reactivate
    with_lock do
      if cancelled?
        run_callbacks :reactivate do
          cancellation = self.cancellation #: as !nil
          cancellation.destroy
        end
      end
    end
  end

  #: () -> bool
  def cancelled?
    cancellation.present?
  end

  #: () -> bool
  def cancellable?
    Account.accepting_signups?
  end
end
