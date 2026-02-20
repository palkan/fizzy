class Columns::LeftPositionsController < ApplicationController
  include ColumnScoped

  before_action :ensure_contributor

  def create
    @left_column = @column.left_column
    @column.move_left
  end
end
