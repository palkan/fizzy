# typed: true

# @requires_ancestor: Board
module Board::Triageable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Board)
    has_many :columns, dependent: :destroy
  end
end
