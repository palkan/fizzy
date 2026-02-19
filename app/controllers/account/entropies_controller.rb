class Account::EntropiesController < ApplicationController
  verify_authorized

  before_action :ensure_can_manage_account

  def update
    Current.account.entropy.update!(entropy_params)
    redirect_to account_settings_path, notice: "Account updated"
  end

  private
    def entropy_params
      params.expect(entropy: [ :auto_postpone_period ])
    end
end
