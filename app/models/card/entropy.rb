class Card::Entropy
  attr_reader :card #: Card
  attr_reader :auto_clean_period #: Integer

  #: (Card) -> Card::Entropy?
  def self.for(card)
    return unless card.last_active_at

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
