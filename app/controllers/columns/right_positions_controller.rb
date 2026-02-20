class Columns::RightPositionsController < ApplicationController
  include ColumnScoped

  before_action :ensure_contributor

  def create
    @right_column = @column.right_column
    @column.move_right
  end
end
