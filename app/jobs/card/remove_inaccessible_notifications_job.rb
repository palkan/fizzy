class Card::RemoveInaccessibleNotificationsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  #: (Card) -> void
  def perform(card)
    card.remove_inaccessible_notifications
  end
end
