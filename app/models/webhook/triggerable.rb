# typed: true

# @requires_ancestor: Webhook
module Webhook::Triggerable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Webhook)
    scope :triggered_by, ->(event) { where(board: event.board).triggered_by_action(event.action) }
    scope :triggered_by_action, ->(action) { where("subscribed_actions LIKE ?", "%\"#{action}\"%") }
  end

  def trigger(event)
    deliveries.create!(event: event) unless account.cancelled?
  end
end
