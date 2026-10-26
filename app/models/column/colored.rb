# typed: true

# @requires_ancestor: Column
module Column::Colored
  extend ActiveSupport::Concern

  DEFAULT_COLOR = Color::COLORS.first

  included do
    #: self as singleton(Column)
    before_validation -> {
      #: self as Column
      self[:color] ||= DEFAULT_COLOR.value
    }
  end

  def color
    Color.for_value(super) || DEFAULT_COLOR
  end
end
