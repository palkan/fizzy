class Cards::NotNowsController < ApplicationController
  include CardScoped

  verify_authorized

  def create
    authorize! @card, to: :manage?
    capture_card_location
    @card.postpone
    refresh_stream_if_needed

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
