# typed: true

class QrCodeLink
  #: String
  attr_reader :url

  #: (String signed) -> QrCodeLink
  def self.from_signed(signed)
    new verifier.verify(signed, purpose: :qr_code)
  end

  #: () -> ActiveSupport::MessageVerifier
  def self.verifier
    ActiveSupport::MessageVerifier.new(secret, url_safe: true)
  end

  #: () -> String
  private_class_method def self.secret
    Rails.application.key_generator.generate_key("qr_codes")
  end

  #: (String url) -> void
  def initialize(url)
    @url = url
  end

  #: () -> String
  def signed
    self.class.verifier.generate(@url, purpose: :qr_code)
  end
end
