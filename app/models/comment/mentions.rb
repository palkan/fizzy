module Comment::Mentions
  # @type instance: Comment
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Comment)
    include ::Mentions

    def mentionable?
      card.published?
    end
  end
end
