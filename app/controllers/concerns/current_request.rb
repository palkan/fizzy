# typed: true

# @requires_ancestor: ApplicationController
module CurrentRequest
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationController)
    before_action do
      #: self as ApplicationController
      Current.http_method = request.method
      Current.request_id  = request.uuid
      Current.user_agent  = request.user_agent
      Current.ip_address  = request.ip
      Current.referrer    = request.referrer
    end
  end
end
