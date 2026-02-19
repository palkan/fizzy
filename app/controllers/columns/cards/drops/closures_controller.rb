class Columns::Cards::Drops::ClosuresController < ApplicationController
  include CardScoped

  verify_authorized

  def create
    authorize! @card, to: :manage?

    @card.close
  end
end
