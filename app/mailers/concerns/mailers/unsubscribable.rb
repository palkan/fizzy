module Mailers::Unsubscribable
  # @type instance: Notification::BundleMailer
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Notification::BundleMailer)
    after_action :set_unsubscribe_headers
  end

  #: () -> void
  def set_unsubscribe_headers
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    headers["List-Unsubscribe"]      = "<#{notifications_unsubscribe_url(access_token: @unsubscribe_token)}>"
  end
end
