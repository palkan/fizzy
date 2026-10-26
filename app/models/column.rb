# typed: true

class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :account, default: -> {
    #: self as Column
    board.account
  }
  belongs_to :board, touch: true
  has_many :cards, dependent: :nullify

  after_save_commit -> {
    #: self as Column
    cards.touch_all
  }, if: -> {
    #: self as Column
    saved_change_to_name? || saved_change_to_color?
  }
  after_destroy_commit -> {
    #: self as Column
    board.cards.touch_all
  }
end
