class Columns::LeftPositionsController < ApplicationController
  include ColumnScoped

  verify_authorized

  def create
    authorize! @column, to: :manage?
    @left_column = @column.left_column
    @column.move_left
  end
end
