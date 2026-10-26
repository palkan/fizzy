# typed: true

class Watch < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Watch
    user.account
  }
  belongs_to :user
  belongs_to :card, touch: true

  scope :watching, -> { where(watching: true) }
  scope :not_watching, -> { where(watching: false) }
end
