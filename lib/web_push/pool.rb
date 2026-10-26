# typed: true

# This is in lib so we can use it in a thread pool without the Rails executor
class WebPush::Pool
  #: Concurrent::ThreadPoolExecutor
  attr_reader :delivery_pool
  #: Concurrent::FixedThreadPool
  attr_reader :invalidation_pool
  #: Net::HTTP::Persistent
  attr_reader :connection
  #: ^(String) -> void
  attr_reader :invalid_subscription_handler

  #: (invalid_subscription_handler: ^(String) -> void) -> void
  def initialize(invalid_subscription_handler:)
    @delivery_pool = Concurrent::ThreadPoolExecutor.new(max_threads: 50, queue_size: 10000)
    @invalidation_pool = Concurrent::FixedThreadPool.new(1)
    @connection = Net::HTTP::Persistent.new(name: "web_push", pool_size: 150)
    @invalid_subscription_handler = invalid_subscription_handler
  end

  #: (Hash[Symbol, untyped], Push::Subscription::PrivateRelation | Push::Subscription::PrivateCollectionProxy) -> void
  def queue(payload, subscriptions)
    subscriptions.find_each do |subscription|
      deliver_later(payload, subscription)
    end
  end

  #: () -> void
  def shutdown
    connection.shutdown
    shutdown_pool(delivery_pool)
    shutdown_pool(invalidation_pool)
  end

  private
    #: (Hash[Symbol, untyped], Push::Subscription) -> void
    def deliver_later(payload, subscription)
      # Ensure any AR operations happen before we post to the thread pool
      notification = subscription.notification(title: payload[:title], body: payload[:body], url: payload[:url])
      subscription_id = subscription.id

      delivery_pool.post do
        deliver(notification, subscription_id)
      rescue Exception => e
        Rails.logger.error "Error in WebPush::Pool.deliver: #{e.class} #{e.message}"
      end
    rescue Concurrent::RejectedExecutionError
    end

    #: (WebPush::Notification, String) -> void
    def deliver(notification, id)
      notification.deliver(connection: connection)
    rescue WebPush::ExpiredSubscription, OpenSSL::OpenSSLError => ex
      invalidate_subscription_later(id) if invalid_subscription_handler
    end

    #: (String) -> void
    def invalidate_subscription_later(id)
      invalidation_pool.post do
        invalid_subscription_handler.call(id)
      rescue Exception => e
        Rails.logger.error "Error in WebPush::Pool.invalid_subscription_handler: #{e.class} #{e.message}"
      end
    end

    #: (Concurrent::ThreadPoolExecutor | Concurrent::FixedThreadPool) -> void
    def shutdown_pool(pool)
      pool.shutdown
      pool.kill unless pool.wait_for_termination(1)
    end
end
