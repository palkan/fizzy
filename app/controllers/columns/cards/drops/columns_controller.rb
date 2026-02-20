class Columns::Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  before_action :ensure_contributor

  def create
    @column = @card.board.columns.find(params[:column_id])
    @card.triage_into(@column)
  end
end
