module RoutingHeaders
  # @type instance: ApplicationController
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationController)
    before_action :set_target_header
  end

  private
    def set_target_header
      response.headers["X-Kamal-Target"] = request.headers["X-Kamal-Target"]
    end
end
