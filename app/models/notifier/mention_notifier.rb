# typed: true

class Notifier::MentionNotifier < Notifier
  # Notifier.for builds mention notifiers for mentions only
  #: () -> Mention
  def source
    super #: as Mention
  end

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
