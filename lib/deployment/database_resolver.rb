# typed: true

module Deployment
  class DatabaseResolver < ActiveRecord::Middleware::DatabaseSelector::Resolver
    #: () -> bool
    def self.in_primary_datacenter?
      ENV["PRIMARY_DATACENTER"].present? || Rails.env.local?
    end

    #: (ActionDispatch::Request) -> bool
    def reading_request?(request)
      # Disables writes (and so primary-DB stickiness) in non-primary datacenters
      super || !DatabaseResolver.in_primary_datacenter?
    end

    private
      #: () -> bool?
      def read_from_primary?
        # Only the primary datacenter can read from the primary database, non-primary DCs have local DB replicas
        super && DatabaseResolver.in_primary_datacenter?
      end
  end
end
