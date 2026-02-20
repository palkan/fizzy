class Columns::Cards::Drops::ClosuresController < ApplicationController
  include CardScoped

  before_action :ensure_contributor

  def create
    @card.close
  end
end
