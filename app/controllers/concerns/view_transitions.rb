# FIXME: Upstream this fix to turbo-rails
module ViewTransitions
  # @type instance: ApplicationController
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationController)
    before_action :disable_view_transitions, if: :page_refresh?
  end

  private
    def disable_view_transitions
      @disable_view_transition = true
    end

    #: () -> bool
    def page_refresh?
      request.referrer.present? && request.referrer == request.url
    end
end
