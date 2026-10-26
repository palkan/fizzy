# typed: true

# @requires_ancestor: ApplicationController
module SetPlatform
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationController)
    helper_method :platform
  end

  private
    #: () -> ApplicationPlatform
    def platform
      @platform ||= ApplicationPlatform.new(cookies[:x_user_agent].presence || request.user_agent)
    end
end
