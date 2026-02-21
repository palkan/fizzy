class Cards::ColumnsController < ApplicationController
  include CardScoped

  verify_authorized

  def edit
    authorize! @card, to: :manage?
    @columns = @card.board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end
end
