# typed: true

class Card::ActivitySpike < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Card::ActivitySpike
    card.account
  }
  belongs_to :card, touch: true
end
