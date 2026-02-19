class Boards::Columns::NotNowsController < ApplicationController
  include BoardScoped

  verify_authorized

  def show
    set_page_and_extract_portion_from @board.cards.postponed.latest.preloaded
    fresh_when etag: @page.records
  end
end
