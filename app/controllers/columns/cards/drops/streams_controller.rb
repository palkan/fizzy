class Columns::Cards::Drops::StreamsController < ApplicationController
  include CardScoped

  verify_authorized

  def create
    authorize! @card, to: :manage?

    @card.send_back_to_triage
    set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first
  end
end
