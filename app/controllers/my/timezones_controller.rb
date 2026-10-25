class My::TimezonesController < ApplicationController
  def update
    # Only system users lack settings, and they never make requests
    settings = Current.user!.settings #: User::Settings
    settings.update!(timezone_name: timezone_param)
    head :no_content
  end

  private
    def timezone_param
      params[:timezone_name]
    end
end
