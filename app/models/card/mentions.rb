module Card::Mentions
  # @type instance: Card
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Card)
    include ::Mentions

    def mentionable?
      published?
    end

    def should_check_mentions?
      was_just_published? #: bool
    end
  end
end
