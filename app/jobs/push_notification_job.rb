class PushNotificationJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  #: (Notification) -> void
  def perform(notification)
    notification.push
  end
end
