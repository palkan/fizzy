class Webhook::Delivery < ApplicationRecord
  # @rbs skip -- declared in sig/generated/inline.rbs
  include Rails.application.routes.url_helpers

  class ResponseTooLarge < StandardError; end

  STALE_TRESHOLD = 7.days
  USER_AGENT = "fizzy/1.0.0 Webhook"
  ENDPOINT_TIMEOUT = 7.seconds
  MAX_RESPONSE_SIZE = 100.kilobytes

  belongs_to :account, default: -> { webhook.account }
  belongs_to :webhook
  belongs_to :event

  store :request, coder: JSON
  store :response, coder: JSON

  enum :state, %w[ pending in_progress completed errored ].index_by(&:itself), default: :pending

  scope :ordered, -> { order created_at: :desc, id: :desc }
  scope :stale, -> { where(created_at: ...STALE_TRESHOLD.ago) }

  after_create_commit :deliver_later

  #: (?batch_size: Integer, ?pause: Float | Integer) -> void
  def self.cleanup(batch_size: 500, pause: 0.1)
    sleep pause until stale.limit(batch_size).delete_all.zero?
  end

  #: () -> void
  def deliver_later
    Webhook::DeliveryJob.perform_later(self)
  end

  #: () -> void
  def deliver
    in_progress!

    self.request[:headers] = headers
    self.response = perform_request
    self.state = :completed
    save!

    webhook.delinquency_tracker.record_delivery_of(self)
  rescue
    errored!
    raise
  end

  #: () -> { headers: Hash[String, String] }?
  def sanitized_request
    if headers = request&.dig("headers")&.except("X-Webhook-Signature")
      { headers: headers }
    end
  end

  #: () -> { code: Integer?, error: Symbol? }?
  def response_summary
    if response.present?
      { code: response[:code], error: response[:error] }
    end
  end

  #: () -> bool
  def failed?
    (errored? || completed?) && !succeeded?
  end

  #: () -> bool
  def succeeded?
    completed? && response[:error].blank? && response[:code].between?(200, 299)
  end

  private
    #: () -> Hash[Symbol, untyped]
    def perform_request
      if resolved_ip.nil?
        { error: :private_uri }
      else
        request = Net::HTTP::Post.new(uri, headers).tap { |request| request.body = payload }

        response = http.request(request) do |net_http_response|
          stream_body_with_limit(net_http_response)
        end

        { code: response.code.to_i }
      end
    rescue ResponseTooLarge
      { error: :response_too_large }
    rescue Resolv::ResolvTimeout, Resolv::ResolvError, SocketError
      { error: :dns_lookup_failed }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT
      { error: :connection_timeout }
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNRESET
      { error: :destination_unreachable }
    rescue OpenSSL::SSL::SSLError
      { error: :failed_tls }
    end

    #: (Net::HTTPResponse) -> void
    def stream_body_with_limit(response)
      bytes_read = 0
      response.read_body do |chunk|
        bytes_read += chunk.bytesize
        raise ResponseTooLarge if bytes_read > MAX_RESPONSE_SIZE
      end
    end

    #: () -> String?
    def resolved_ip
      return @resolved_ip if defined?(@resolved_ip)
      @resolved_ip = if host = uri.host
        SsrfProtection.resolve_public_ip(host)
      end
    end

    #: () -> URI::Generic
    def uri
      @uri ||= URI(webhook.url)
    end

    #: () -> Net::HTTP
    def http
      # Only called once resolved_ip has resolved the host, so it's present
      host = uri.host #: String
      Net::HTTP.new(host, uri.port).tap do |http|
        http.ipaddr = resolved_ip
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = ENDPOINT_TIMEOUT
        http.read_timeout = ENDPOINT_TIMEOUT
      end
    end

    #: () -> Hash[String, String]
    def headers
      {
        "User-Agent" => USER_AGENT,
        "Content-Type" => content_type,
        "X-Webhook-Signature" => signature,
        "X-Webhook-Timestamp" => event.created_at.utc.iso8601
      }
    end

    #: () -> String
    def signature
      OpenSSL::HMAC.hexdigest("SHA256", webhook.signing_secret, payload)
    end

    #: () -> String
    def content_type
      if webhook.for_campfire?
        "text/html"
      elsif webhook.for_basecamp?
        "application/x-www-form-urlencoded"
      else
        "application/json"
      end
    end

    #: () -> String
    def payload
      @payload ||= if webhook.for_basecamp?
        { content: render_payload(formats: :html) }.to_query
      elsif webhook.for_campfire?
        render_payload(formats: :html)
      elsif webhook.for_slack?
        slack_payload
      else
        render_payload(formats: :json)
      end
    end

    #: (**untyped) -> String
    def render_payload(**options)
      webhook.renderer.render(layout: false, template: "webhooks/event", assigns: { event: event }, **options).strip
    end

    #: (String) -> String
    def convert_html_to_mrkdwn(html)
      document = Nokogiri::HTML5(html)

      document.css("a").each do |a|
        if href = a["href"].presence
          a.replace("<#{href.strip}|#{a.text}>")
        end
      end

      document.css("b").each do |b|
        b.replace("*#{b.text}*")
      end

      document.css("i").each do |i|
        i.replace("_#{i.text}_")
      end

      document.text
    end

    #: () -> String
    def slack_payload
      text = event.description_for(nil).to_plain_text
      url = polymorphic_url(event.eventable, base_url_options.merge(script_name: account.slug))

      { text: "#{text} <#{url}|Open in Fizzy>" }.to_json
    end

    #: () -> Hash[Symbol, untyped]
    def base_url_options
      Rails.application.routes.default_url_options.presence ||
        Rails.application.config.action_mailer.default_url_options
    end
end
