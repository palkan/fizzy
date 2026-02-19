class Searches::QueriesController < ApplicationController
  skip_authorization

  def create
    Current.user.remember_search(params[:q])
    head :ok
  end
end
