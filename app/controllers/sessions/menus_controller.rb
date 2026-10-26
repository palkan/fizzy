# typed: true

class Sessions::MenusController < ApplicationController
  disallow_account_scope

  layout "public"

  def show
    @accounts = Current.identity!.accounts.active

    if @accounts.one?
      account = @accounts.first #: as !nil
      redirect_to root_url(script_name: account.slug)
    end
  end
end
