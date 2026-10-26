# typed: true

class Notification::BundleMailer < ApplicationMailer
  include Mailers::Unsubscribable

  helper NotificationsHelper

  #: (Notification::Bundle) -> void
  def notification(bundle)
    @user = bundle.user
    @bundle = bundle
    @notifications = bundle.notifications
      .preload(:card, :creator, source: [ :board, :creator ])
      .reject { |n| n.source.nil? || n.card.nil? }
    @unsubscribe_token = @user.generate_token_for(:unsubscribe)

    if @notifications.any?
      # Bundles only go to active users, who always have an identity
      identity = bundle.user.identity #: as !nil

      mail \
        to: identity.email_address,
        subject: "Fizzy#{ " (#{ Current.account!.name })" if identity.accounts.many? }: New notifications"
    end
  end
end
