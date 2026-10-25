module Webhook::Triggerable
  # @type instance: Webhook
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Webhook)
    scope :triggered_by, ->(event) { where(board: event.board).triggered_by_action(event.action) }
    scope :triggered_by_action, ->(action) { where("subscribed_actions LIKE ?", "%\"#{action}\"%") }
  end

  def trigger(event)
    deliveries.create!(event: event) unless account.cancelled?
  end
end
