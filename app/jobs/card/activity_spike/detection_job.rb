# typed: true

class Card::ActivitySpike::DetectionJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  #: (Card) -> void
  def perform(card)
    card.detect_activity_spikes
  end
end
