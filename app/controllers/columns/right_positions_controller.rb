class Columns::RightPositionsController < ApplicationController
  include ColumnScoped

  verify_authorized

  def create
    authorize! @column, to: :manage?
    @right_column = @column.right_column
    @column.move_right
  end
end
