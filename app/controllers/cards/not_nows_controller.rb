class Cards::NotNowsController < ApplicationController
  include CardScoped

  before_action :ensure_contributor

  def create
    capture_card_location
    @card.postpone
    refresh_stream_if_needed

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end
end
