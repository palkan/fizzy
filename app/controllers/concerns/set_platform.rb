module SetPlatform
  # @type instance: ApplicationController
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationController)
    helper_method :platform
  end

  private
    #: () -> ApplicationPlatform
    def platform
      @platform ||= ApplicationPlatform.new(cookies[:x_user_agent].presence || request.user_agent)
    end
end
