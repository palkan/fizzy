# typed: true

# FIXME: This should move upstream to Rails. It's a good pattern.
# @requires_ancestor: ApplicationController
module CurrentTimezone
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationController)
    around_action :set_current_timezone

    helper_method :timezone_from_cookie

    etag do
      #: self as ApplicationController
      timezone_from_cookie
    end
  end

  private
    #: () { () -> void } -> void
    def set_current_timezone(&)
      Time.use_zone(timezone_from_cookie, &)
    end

    #: () -> ActiveSupport::TimeZone?
    def timezone_from_cookie
      @timezone_from_cookie ||= begin
        timezone = cookies[:timezone]
        ActiveSupport::TimeZone[timezone] if timezone.present?
      end
    end
end
