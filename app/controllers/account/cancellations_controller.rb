class Account::CancellationsController < ApplicationController
  verify_authorized

  def create
    authorize! Current.account, to: :destroy?
    Current.account.cancel
    redirect_to session_menu_path(script_name: nil), notice: "Account deleted"
  end
end
