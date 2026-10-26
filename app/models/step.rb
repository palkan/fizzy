# typed: true

class Step < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Step
    card.account
  }
  belongs_to :card, touch: true

  scope :completed, -> { where(completed: true) }

  validates :content, presence: true

  #: () -> bool
  def completed?
    completed
  end
end
