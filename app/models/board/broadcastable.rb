# typed: true

# @requires_ancestor: Board
module Board::Broadcastable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Board)
    broadcasts_refreshes
    broadcasts_refreshes_to ->(board) { [ board.account, :all_boards ] }
  end
end
