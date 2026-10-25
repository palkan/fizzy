class Notification::PushJob < ApplicationJob
  #: (Notification) -> void
  def perform(notification)
    notification.push
  end
end
