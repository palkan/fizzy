# typed: true

# @requires_ancestor: ApplicationController
module TurboFlash
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationController)
    helper_method :turbo_stream_flash
  end

  private
    #: (**untyped) -> untyped
    def turbo_stream_flash(**flash_options)
      turbo_stream.replace(:flash, partial: "layouts/shared/flash", locals: { flash: flash_options })
    end
end
