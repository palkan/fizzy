class Columns::Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  verify_authorized

  def create
    authorize! @card, to: :manage?

    @column = @card.board.columns.find(params[:column_id])
    @card.triage_into(@column)
  end
end
