class Boards::EntropiesController < ApplicationController
  include BoardScoped

  verify_authorized

  def update
    authorize! @board
    @board.update!(entropy_params)
  end

  private
    def entropy_params
      params.expect(board: [ :auto_postpone_period ])
    end
end
