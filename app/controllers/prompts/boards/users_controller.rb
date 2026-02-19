class Prompts::Boards::UsersController < ApplicationController
  include BoardScoped

  verify_authorized

  def index
    @users = @board.users.active.alphabetically

    if stale? etag: @users
      render layout: false
    end
  end
end
