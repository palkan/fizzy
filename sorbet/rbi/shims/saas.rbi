# typed: true

# Defined by the SaaS engine (saas/) and the gems only it bundles, which Sorbet doesn't check

class FreeV1Subscription
  sig { returns(String) }
  def self.to_param; end

  sig { returns(T.untyped) }
  def self.price; end
end

module Sentry
  sig { params(exception: Exception, options: T.untyped).returns(T.untyped) }
  def self.capture_exception(exception, **options); end
end
