class Columns::Cards::Drops::NotNowsController < ApplicationController
  include CardScoped

  verify_authorized

  def create
    authorize! @card, to: :manage?

    @card.postpone
  end
end
