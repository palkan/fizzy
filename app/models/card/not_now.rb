# typed: true

class Card::NotNow < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Card::NotNow
    card.account
  }
  belongs_to :card, class_name: "::Card", touch: true
  belongs_to :user, optional: true
end
