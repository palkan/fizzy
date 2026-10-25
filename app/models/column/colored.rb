module Column::Colored
  # @type instance: Column
  extend ActiveSupport::Concern

  DEFAULT_COLOR = Color::COLORS.first

  included do
    # @type self: singleton(Column)
    before_validation -> { self[:color] ||= DEFAULT_COLOR.value }
  end

  def color
    Color.for_value(super) || DEFAULT_COLOR
  end
end
