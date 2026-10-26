# typed: true

# @requires_ancestor: Board
module Board::Cards
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Board)
    has_many :cards, dependent: :destroy

    after_update_commit -> {
      #: self as Board
      cards.touch_all
    }, if: :saved_change_to_name?
  end
end
