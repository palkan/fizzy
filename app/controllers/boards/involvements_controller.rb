class Boards::InvolvementsController < ApplicationController
  include BoardScoped

  verify_authorized

  def update
    authorize! @board, to: :manage?
    @board.access_for(Current.user).update!(involvement: params[:involvement])
  end
end
