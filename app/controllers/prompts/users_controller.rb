class Prompts::UsersController < ApplicationController
  skip_authorization

  def index
    @users = Current.account.users.active.alphabetically

    if stale? etag: @users
      render layout: false
    end
  end
end
