class Account::JoinCodesController < ApplicationController
  verify_authorized

  before_action :set_join_code
  before_action :ensure_can_manage_account, only: %i[ update destroy ]

  def show
  end

  def edit
  end

  def update
    if @join_code.update(join_code_params)
      redirect_to account_join_code_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @join_code.reset
    redirect_to account_join_code_path
  end

  private
    def set_join_code
      @join_code = Current.account.join_code
      authorize! Current.account, to: :show?
    end

    def join_code_params
      params.expect account_join_code: [ :usage_limit ]
    end
end
