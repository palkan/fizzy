class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  # @rbs skip -- declared in sig/generated/inline.rbs
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  # @rbs skip -- declared in sig/generated/inline.rbs
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern
end
