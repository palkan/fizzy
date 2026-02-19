class Users::RolesController < ApplicationController
  verify_authorized

  before_action :set_user

  def update
    authorize! @user, to: :change_role?
    @user.update!(role_params)
    redirect_to account_settings_path
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id])
    end

    def role_params
      { role: params.require(:user)[:role].presence_in(%w[ member admin ]) || "member" }
    end
end
