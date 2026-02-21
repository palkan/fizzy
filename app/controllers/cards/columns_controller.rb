class Cards::ColumnsController < ApplicationController
  include CardScoped

  verify_authorized

  def edit
    authorize! @card, to: :manage?
    @columns = @card.board.columns.sorted.accessible_by(Current.user)

    fresh_when etag: [ @card, @columns ]
  end
end
