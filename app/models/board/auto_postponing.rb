# typed: true

# @requires_ancestor: Board
module Board::AutoPostponing
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Board)
    before_create :set_default_auto_postpone_period
  end

  private
    def set_default_auto_postpone_period
      self.auto_postpone_period ||= Entropy::DEFAULT_AUTO_POSTPONE_PERIOD_IN_DAYS.days unless attribute_present?(:auto_postpone_period)
    end
end
