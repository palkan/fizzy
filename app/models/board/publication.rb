# typed: true

class Board::Publication < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Board::Publication
    board.account
  }
  belongs_to :board, touch: true

  has_secure_token :key
end
