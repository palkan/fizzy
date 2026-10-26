# typed: true

# @requires_ancestor: Card
module Card::Stallable
  extend ActiveSupport::Concern

  STALLED_AFTER_LAST_SPIKE_PERIOD = 14.days

  included do
    #: self as singleton(Card)
    has_one :activity_spike, class_name: "Card::ActivitySpike", dependent: :destroy

    scope :with_activity_spikes, -> { joins(:activity_spike) }
    scope :stalled, -> { open.active.with_activity_spikes.where(card_activity_spikes: { updated_at: ..STALLED_AFTER_LAST_SPIKE_PERIOD.ago }, updated_at: ..STALLED_AFTER_LAST_SPIKE_PERIOD.ago) }

    before_update :remember_to_detect_activity_spikes
    after_update_commit :detect_activity_spikes_later, if: :should_detect_activity_spikes?
  end

  # Keep in sync with #isStalled in app/javascript/controllers/bubble_controller.js
  #: () -> bool?
  def stalled?
    if activity_spike = self.activity_spike
      open? && activity_spike.updated_at < STALLED_AFTER_LAST_SPIKE_PERIOD.ago && updated_at < STALLED_AFTER_LAST_SPIKE_PERIOD.ago
    end
  end

  #: () -> ActiveSupport::TimeWithZone?
  def last_activity_spike_at
    activity_spike&.updated_at
  end

  #: () -> bool
  def detect_activity_spikes
    card = self #: as Card
    Card::ActivitySpike::Detector.new(card).detect
  end

  private
    def remember_to_detect_activity_spikes
      @should_detect_activity_spikes = published? && last_active_at_changed?
    end

    def should_detect_activity_spikes?
      @should_detect_activity_spikes
    end

    def detect_activity_spikes_later
      card = self #: as Card
      Card::ActivitySpike::DetectionJob.perform_later(card)
    end
end
