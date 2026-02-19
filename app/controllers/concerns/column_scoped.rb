module ColumnScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_column
    authorize :board, through: -> { @board }
  end

  private
    def set_column
      @column = Current.account.columns.find(params[:column_id])
      @board = @column.board
      authorize! @column, to: :show?
    end
end
