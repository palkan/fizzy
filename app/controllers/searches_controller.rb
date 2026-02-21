class SearchesController < ApplicationController
  include Turbo::DriveHelper

  skip_authorization

  def show
    if card = Current.user.accessible_cards.find_by_id(params[:q])
      if card.column && !card.column.accessible_to?(Current.user)
        set_page_and_extract_portion_from Current.user.search(params[:q])
      else
        @card = card
      end
    else
      set_page_and_extract_portion_from Current.user.search(params[:q])
    end
    @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
  end
end
