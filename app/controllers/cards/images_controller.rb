class Cards::ImagesController < ApplicationController
  include CardScoped

  verify_authorized

  def destroy
    authorize! @card, to: :manage?
    @card.image.purge_later

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end
end
