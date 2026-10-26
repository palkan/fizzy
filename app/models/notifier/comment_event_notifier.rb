# typed: true

class Notifier::CommentEventNotifier < Notifier
  delegate :creator, to: :source

  # Notifier.for builds event notifiers for events only
  #: () -> Event
  def source
    super #: as Event
  end

  private
    def recipients
      card.watchers.without(creator, *source.eventable.scan_mentionees)
    end

    def card
      source.eventable.card
    end
end
