class TagsController < ApplicationController
  skip_authorization

  def index
    set_page_and_extract_portion_from Current.account.tags.alphabetically
  end
end
