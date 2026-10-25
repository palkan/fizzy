module Card::Colored
  # @type instance: Card
  extend ActiveSupport::Concern

  def color
    column&.color || Column::Colored::DEFAULT_COLOR
  end
end
