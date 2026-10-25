class Notification::Bundle::DeliverJob < ApplicationJob
  include SmtpDeliveryErrorHandling

  queue_as :backend

  discard_on ActiveJob::DeserializationError

  #: (Notification::Bundle) -> void
  def perform(bundle)
    bundle.deliver
  end
end
