# typed: true

class AccountMailer < ApplicationMailer
  #: (Account::Cancellation) -> void
  def cancellation(cancellation)
    @account = cancellation.account
    @user = cancellation.initiated_by
    # Cancellations are initiated by active users, who always have an identity
    identity = @user.identity #: as !nil

    mail(
      to: identity.email_address,
      subject: "Your Fizzy account was cancelled"
    )
  end
end
