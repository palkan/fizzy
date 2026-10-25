class Push::Subscription < ApplicationRecord
  PERMITTED_ENDPOINT_HOSTS = %w[
    jmt17.google.com
    fcm.googleapis.com
    updates.push.services.mozilla.com
    web.push.apple.com
    notify.windows.com
  ].freeze

  belongs_to :account, default: -> { user.account }
  belongs_to :user

  validates :endpoint, presence: true
  validate :validate_endpoint_url

  #: (title: String, body: String, url: String) -> WebPush::Notification
  def notification(title:, body:, url:)
    WebPush::Notification.new(
      title: title,
      body: body,
      url: url,
      badge: user.notifications.unread.count,
      endpoint: endpoint, #: String
      endpoint_ip: resolved_endpoint_ip,
      p256dh_key: p256dh_key, #: String
      auth_key: auth_key #: String
    )
  end

  #: () -> String?
  def resolved_endpoint_ip
    return @resolved_endpoint_ip if defined?(@resolved_endpoint_ip)
    # Only resolved for endpoints with a permitted host (see #validate_endpoint_url)
    host = endpoint_uri&.host #: String
    @resolved_endpoint_ip = SsrfProtection.resolve_public_ip(host)
  end

  private
    #: () -> URI::Generic?
    def endpoint_uri
      if endpoint = self.endpoint.presence
        @endpoint_uri ||= URI.parse(endpoint)
      end
    rescue URI::InvalidURIError
      nil
    end

    def validate_endpoint_url
      uri = endpoint_uri

      if uri.nil?
        errors.add(:endpoint, "is not a valid URL")
      elsif uri.scheme != "https"
        errors.add(:endpoint, "must use HTTPS")
      elsif !permitted_endpoint_host?
        errors.add(:endpoint, "is not a permitted push service")
      elsif resolved_endpoint_ip.nil?
        errors.add(:endpoint, "resolves to a private or invalid IP address")
      end
    end

    #: () -> bool
    def permitted_endpoint_host?
      host = endpoint_uri&.host&.downcase
      PERMITTED_ENDPOINT_HOSTS.any? { |permitted| host&.end_with?(permitted) }
    end
end
