class UsersController < ApplicationController
  verify_authorized except: :index

  before_action :set_user, except: %i[ index ]

  def index
    set_page_and_extract_portion_from Current.account.users.active.alphabetically
  end

  def show
  end

  def edit
  end

  def update
    authorize! @user
    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to @user }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize! @user
    @user.deactivate

    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.json { head :no_content }
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:id])
      authorize! @user, to: :show?
    end

    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end
