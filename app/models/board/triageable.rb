module Board::Triageable
  # @type instance: Board
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Board)
    has_many :columns, dependent: :destroy
  end
end
