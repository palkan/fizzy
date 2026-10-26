# typed: true

# @requires_ancestor: Card
module Card::Colored
  extend ActiveSupport::Concern

  def color
    column&.color || Column::Colored::DEFAULT_COLOR
  end
end
