# typed: true

# @requires_ancestor: Card
module Card::Mentions
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Card)
    include ::Mentions

    def mentionable?
      published?
    end

    def should_check_mentions?
      was_just_published?
    end
  end
end
