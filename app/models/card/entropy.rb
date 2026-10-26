# typed: true

class Card::Entropy
  #: Card
  attr_reader :card
  #: Integer
  attr_reader :auto_clean_period

  #: (Card) -> Card::Entropy?
  def self.for(card)
    # Unset until the card is first saved
    last_active_at = card.last_active_at #: ActiveSupport::TimeWithZone?
    return unless last_active_at

    new(card, card.auto_postpone_period)
  end

  #: (Card, Integer) -> void
  def initialize(card, auto_clean_period)
    @card = card
    @auto_clean_period = auto_clean_period
  end

  #: () -> ActiveSupport::TimeWithZone
  def auto_clean_at
    card.last_active_at + auto_clean_period
  end

  #: () -> Integer
  def days_before_reminder
    (auto_clean_period * 0.25).seconds.in_days.round
  end
end
