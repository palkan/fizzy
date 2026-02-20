class Columns::Cards::Drops::NotNowsController < ApplicationController
  include CardScoped

  before_action :ensure_contributor

  def create
    @card.postpone
  end
end
