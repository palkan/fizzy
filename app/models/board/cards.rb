module Board::Cards
  # @type instance: Board
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Board)
    has_many :cards, dependent: :destroy

    after_update_commit -> { cards.touch_all }, if: :saved_change_to_name?
  end
end
