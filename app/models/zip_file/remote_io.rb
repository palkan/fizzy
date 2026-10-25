class ZipFile::RemoteIO < ZipKit::RemoteIO
  # @rbs @ssl_verify_peer: bool

  #: (String | URI::Generic, ?ssl_verify_peer: bool) -> void
  def initialize(url, ssl_verify_peer: true)
    super(url)
    @ssl_verify_peer = ssl_verify_peer
  end

  protected
    def request_range(range)
      with_http do |http|
        request = Net::HTTP::Get.new(@uri)
        request.range = range
        response = http.request(request)

        case response.code
        when "206", "200"
          response.body
        else
          raise "Remote at #{@uri} replied with code #{response.code}"
        end
      end
    end

    def request_object_size
      with_http do |http|
        request = Net::HTTP::Get.new(@uri)
        request.range = 0..0
        response = http.request(request)

        case response.code
        when "206"
          # 206 responses carry a Content-Range
          content_range_header_value = response["Content-Range"] #: String
          content_range_header_value.split("/").last.to_i
        when "200"
          response["Content-Length"].to_i
        else
          raise "Remote at #{@uri} replied with code #{response.code}"
        end
      end
    end

  private
    # @rbs [T] () { (Net::HTTP) -> T } -> T
    def with_http
      # Remote zips are read from http(s) URLs
      hostname = @uri.hostname #: String
      http = Net::HTTP.new(hostname, @uri.port)
      http.use_ssl = @uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless @ssl_verify_peer
      http.start { yield http }
    end
end
