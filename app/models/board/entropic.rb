# typed: true

# @requires_ancestor: Board
module Board::Entropic
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Board)
    has_one :entropy, as: :container, dependent: :destroy
  end

  delegate :auto_postpone_period, :auto_postpone_period_in_days, to: :entropy

  def entropy
    super || account.entropy
  end

  def auto_postpone_period=(new_value)
    entropy ||= association(:entropy).reader || self.build_entropy
    entropy.update! auto_postpone_period: new_value
  end

  def auto_postpone_period_in_days=(value)
    self.auto_postpone_period = value.to_i.days.to_i
  end
end
