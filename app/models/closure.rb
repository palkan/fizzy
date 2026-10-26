# typed: true

class Closure < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Closure
    card.account
  }
  belongs_to :card, touch: true
  belongs_to :user, optional: true
end
