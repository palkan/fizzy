class Notifier::MentionNotifier < Notifier
  # @type instance: Notifier::MentionNotifier & Notifier::_MentionSource

  alias mention source

  private
    def recipients
      if mention.self_mention?
        []
      else
        [ mention.mentionee ]
      end
    end

    def creator
      mention.mentioner
    end
end
