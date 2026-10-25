module EntropyHelper
  # @type instance: ActionView::Base
  #: (Card) -> Hash[Symbol, untyped]
  def entropy_bubble_options_for(card)
    {
      daysBeforeReminder: card.entropy.days_before_reminder,
      closesAt: card.entropy.auto_clean_at.iso8601,
      action: "Closes"
    }
  end

  #: (Card) -> Hash[Symbol, untyped]?
  def stalled_bubble_options_for(card)
    if last_activity_spike_at = card.last_activity_spike_at
      {
        stalledAfterDays: card.entropy.days_before_reminder,
        lastActivitySpikeAt: last_activity_spike_at.iso8601,
        updatedAt: card.updated_at.iso8601,
        action: "Stalled"
      }
    end
  end
end
