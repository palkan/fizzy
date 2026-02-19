class My::TimezonesController < ApplicationController
  skip_authorization

  def update
    Current.user.settings.update!(timezone_name: timezone_param)
  end

  private
    def timezone_param
      params[:timezone_name]
    end
end
