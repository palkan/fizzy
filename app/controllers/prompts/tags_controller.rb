class Prompts::TagsController < ApplicationController
  skip_authorization

  def index
    @tags = Current.account.tags.all.alphabetically

    if stale? etag: @tags
      render layout: false
    end
  end
end
