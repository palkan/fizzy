# typed: true

class Notification::PushTarget
  #: Notification
  attr_reader :notification

  delegate :card, to: :notification

  #: (Notification) -> void
  def self.process(notification)
    new(notification).process
  end

  #: (Notification) -> void
  def initialize(notification)
    @notification = notification
  end

  #: () -> void
  def process
    raise NotImplementedError
  end
end
