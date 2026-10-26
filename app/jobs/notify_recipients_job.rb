# typed: true

class NotifyRecipientsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  #: (Event | Mention) -> void
  def perform(notifiable)
    notifiable.notify_recipients
  end
end
