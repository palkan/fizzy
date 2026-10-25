module Board::Broadcastable
  # @type instance: Board
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Board)
    broadcasts_refreshes
    broadcasts_refreshes_to ->(board) { [ board.account, :all_boards ] }
  end
end
