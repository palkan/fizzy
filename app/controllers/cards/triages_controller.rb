class Cards::TriagesController < ApplicationController
  include CardScoped

  verify_authorized

  def create
    authorize! @card, to: :manage?
    column = @card.board.columns.find(params[:column_id])
    @card.triage_into(column)

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end

  def destroy
    authorize! @card, to: :manage?
    @card.send_back_to_triage

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end
end
