# typed: true

# @requires_ancestor: Card
module Card::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    #: self as singleton(Card)
    before_create do
      # Unset until the card is first saved
      last_active_at = self.last_active_at #: ActiveSupport::TimeWithZone?
      created_at = self.created_at #: ActiveSupport::TimeWithZone?
      self.last_active_at = created_at || Time.current unless last_active_at
    end

    after_save :track_title_change, if: :saved_change_to_title?
  end

  #: (Event) -> void
  def event_was_created(event)
    transaction do
      create_system_comment_for(event)
      touch_last_active_at unless was_just_published?
    end
  end

  #: () -> void
  def touch_last_active_at
    # Not using touch so that we can detect attribute change on callbacks
    update!(last_active_at: Time.current)
  end

  private
    def should_track_event?
      published?
    end

    def track_title_change
      if title_before_last_save.present?
        track_event "title_changed", particulars: { old_title: title_before_last_save, new_title: title }
      end
    end

    def create_system_comment_for(event)
      card = self #: as Card
      SystemCommenter.new(card, event).comment
    end
end
