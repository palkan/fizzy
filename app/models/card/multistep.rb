module Card::Multistep
  # @type instance: Card
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Card)
    has_many :steps, dependent: :destroy
  end
end
