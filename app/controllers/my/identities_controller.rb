class My::IdentitiesController < ApplicationController
  skip_authorization
  disallow_account_scope

  def show
    @identity = Current.identity
  end
end
