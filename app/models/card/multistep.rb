# typed: true

# @requires_ancestor: Card
module Card::Multistep
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Card)
    has_many :steps, dependent: :destroy
  end
end
