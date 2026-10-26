# typed: true

class Card::Goldness < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Card::Goldness
    card.account
  }
  belongs_to :card, touch: true
end
