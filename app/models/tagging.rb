# typed: true

class Tagging < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Tagging
    card.account
  }
  belongs_to :tag
  belongs_to :card, touch: true
end
