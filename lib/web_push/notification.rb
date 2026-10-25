class WebPush::Notification
  # @rbs @title: String
  # @rbs @body: String
  # @rbs @url: String
  # @rbs @badge: Integer
  # @rbs @endpoint: String
  # @rbs @endpoint_ip: String?
  # @rbs @p256dh_key: String
  # @rbs @auth_key: String

  #: (title: String, body: String, url: String, badge: Integer, endpoint: String, endpoint_ip: String?, p256dh_key: String, auth_key: String) -> void
  def initialize(title:, body:, url:, badge:, endpoint:, endpoint_ip:, p256dh_key:, auth_key:)
    @title, @body, @url, @badge = title, body, url, badge
    @endpoint, @endpoint_ip, @p256dh_key, @auth_key = endpoint, endpoint_ip, p256dh_key, auth_key
  end

  #: (?connection: Net::HTTP::Persistent?) -> untyped
  def deliver(connection: nil)
    WebPush.payload_send \
      message: encoded_message,
      endpoint: @endpoint, endpoint_ip: @endpoint_ip, p256dh: @p256dh_key, auth: @auth_key,
      vapid: vapid_identification,
      connection: connection,
      urgency: "high"
  end

  private
    #: () -> { subject: String, public_key: String, private_key: String }
    def vapid_identification
      { subject: "mailto:support@fizzy.do" }.merge \
        Rails.configuration.x.vapid.symbolize_keys #: { subject: String, public_key: String, private_key: String }
    end

    #: () -> String
    def encoded_message
      JSON.generate title: @title, options: { body: @body, icon: icon_path, data: { url: @url, path: @url, badge: @badge } }
    end

    #: () -> String
    def icon_path
      "/apple-touch-icon.png"
    end
end
