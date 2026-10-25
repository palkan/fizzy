class Notifier::CommentEventNotifier < Notifier
  # @type instance: Notifier::CommentEventNotifier & Notifier::_EventSource

  delegate :creator, to: :source

  private
    def recipients
      card.watchers.without(creator, *source.eventable.scan_mentionees)
    end

    def card
      source.eventable.card
    end
end
