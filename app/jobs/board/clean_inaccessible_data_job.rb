# typed: true

class Board::CleanInaccessibleDataJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  #: (User, Board) -> void
  def perform(user, board)
    board.clean_inaccessible_data_for(user)
  end
end
