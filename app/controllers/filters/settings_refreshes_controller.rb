class Filters::SettingsRefreshesController < ApplicationController
  include FilterScoped

  skip_authorization

  def create
  end
end
