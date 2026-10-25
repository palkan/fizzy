module RequestForgeryProtection
  # @type instance: ApplicationController
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationController)
    protect_from_forgery using: :header_only, with: :exception
  end

  private
    #: () -> bool
    def verified_via_header_only?
      super || allowed_api_request?
    end

    #: () -> bool
    def allowed_api_request?
      sec_fetch_site_value.nil? && request.format.json?
    end
end
