class Cards::ColumnsController < ApplicationController
  before_action :ensure_contributor

  def edit
    @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    @columns = @card.board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end
end
