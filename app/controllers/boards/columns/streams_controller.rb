class Boards::Columns::StreamsController < ApplicationController
  include BoardScoped

  verify_authorized

  def show
    set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first.preloaded
    fresh_when etag: @page.records
  end
end
