# typed: true

class Pin < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Pin
    user.account
  }
  belongs_to :card
  belongs_to :user

  scope :ordered, -> { order(created_at: :desc) }
end
