# typed: true

class Notification::DefaultPayload
  #: Notification
  attr_reader :notification

  delegate :card, to: :notification

  #: (Notification) -> void
  def initialize(notification)
    @notification = notification
  end

  #: () -> Hash[Symbol, String?]
  def to_h
    { title: title, body: body, url: url }
  end

  #: () -> String?
  def title
    "New notification"
  end

  #: () -> String?
  def body
    "You have a new notification"
  end

  #: () -> String
  def url
    notifications_url
  end

  #: () -> String
  def category
    "default"
  end

  #: () -> bool
  def high_priority?
    false
  end

  #: () -> String
  def base_url
    Rails.application.routes.url_helpers.root_url(**url_options.except(:script_name)).chomp("/")
  end

  #: () -> String
  def avatar_url
    Rails.application.routes.url_helpers.user_avatar_url(notification.creator, **url_options)
  end

  private
    def card_url(card)
      Rails.application.routes.url_helpers.card_url(card, **url_options)
    end

    def notifications_url
      Rails.application.routes.url_helpers.notifications_url(**url_options)
    end

    def url_options
      base_options = Rails.application.routes.default_url_options.presence ||
        Rails.application.config.action_mailer.default_url_options ||
        {}
      base_options.merge(script_name: notification.account.slug)
    end
end
