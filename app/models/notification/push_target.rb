class Notification::PushTarget
  attr_reader :notification #: Notification

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
