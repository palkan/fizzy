# typed: true

# @requires_ancestor: Comment
module Comment::Mentions
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Comment)
    include ::Mentions

    def mentionable?
      card.published?
    end
  end
end
