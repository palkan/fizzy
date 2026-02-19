class Boards::PublicationsController < ApplicationController
  include BoardScoped

  verify_authorized

  def create
    authorize! @board, to: :manage?
    @board.publish
  end

  def destroy
    authorize! @board, to: :manage?
    @board.unpublish
    @board.reload
  end
end
