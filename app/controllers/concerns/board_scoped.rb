module BoardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board
    authorize :board, through: -> { @board }
  end

  private
    def set_board
      @board = Current.account.boards.find(params[:board_id])
      authorize! @board, to: :show?
    end
end
