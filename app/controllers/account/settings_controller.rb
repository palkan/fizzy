class Account::SettingsController < ApplicationController
  verify_authorized

  before_action :set_account
  before_action :ensure_can_manage_account, only: :update

  def show
    authorize! @account, to: :show?
    @users = @account.users.active.alphabetically.includes(:identity)
  end

  def update
    @account.update!(account_params)
    redirect_to account_settings_path
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.expect account: %i[ name ]
    end
end
