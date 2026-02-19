class Cards::PublishesController < ApplicationController
  include CardScoped

  verify_authorized

  def create
    authorize! @card, to: :publish?

    @card.publish

    if add_another_param?
      card = @board.cards.create!(status: :drafted)
      redirect_to card_draft_path(card), notice: "Card added"
    else
      redirect_to @card.board
    end
  end

  private
    def add_another_param?
      params[:creation_type] == "add_another"
    end
end
