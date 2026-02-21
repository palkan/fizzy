class Cards::ColumnsController < ApplicationController
  before_action :ensure_contributor

  def edit
    @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    @columns = @card.board.columns.visible_to(Current.user).sorted

    fresh_when etag: [ @card, @columns ]
  end
end
