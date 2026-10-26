# typed: true

# Framework extensions applied at boot from lib/rails_ext and config/initializers.
# Sorbet doesn't pick up methods from a `prepend` in an RBI, so the prepended modules are declared with `include`.

class ActiveRecord::Base
  include ActiveRecordReplicaSupport
  extend ActiveRecordReplicaSupport::ClassMethods
  extend ActiveRecordBaseOptimizerHintExtensions
end

class ActiveRecord::Relation
  include ActiveRecordRelationOptimizerHintExtensions
  include ActiveRecordRelationPrependOrder
end

class ActiveRecord::AssociationRelation
  include ActiveRecordRelationPrependOrder
end

class ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter
  include MysqlDateArithmetic
end

class ActiveRecord::ConnectionAdapters::SQLite3Adapter
  include SqliteDateArithmetic
end

class ActiveStorage::Blob
  include ActiveStorageBlobServiceUrlForDirectUploadExpiry

  sig { params(user: ::T.nilable(User)).returns(::T::Boolean) }
  def accessible_to?(user); end

  sig { returns(::T::Boolean) }
  def publicly_accessible?; end
end

class ActiveStorage::Attachment
  include Storage::AttachmentTracking

  sig { params(user: ::T.nilable(User)).returns(::T.nilable(::T::Boolean)) }
  def accessible_to?(user); end

  sig { returns(::T.nilable(::T::Boolean)) }
  def publicly_accessible?; end
end

class ActiveStorage::AnalyzeJob
  include ActiveStorageAnalyzeJobSkipDetached
  include ActiveStorageAnalyzeJobSuppressBroadcasts
end

class ActionMailer::MailDeliveryJob
  include SmtpDeliveryErrorHandling
end

class ActionPack::Passkey
  include ActionPackPasskeyInferNameFromAaguid
  extend ActionPackPasskeyInferNameFromAaguid::ClassMethods
end

class Array
  include ChoiceSentenceArrayConversion
end

module ActiveStorage::Authorize
  requires_ancestor { ::ActionController::Base }
  requires_ancestor { ::GeneratedUrlHelpersModule }
  extend ActiveSupport::Concern
  include Authentication
  private

  sig { returns(::T::Boolean) }
  def bearer_token_authenticatable_request?; end

  sig { returns(::T::Boolean) }
  def publicly_accessible_blob?; end

  sig { void }
  def ensure_accessible; end

  sig { params(public: ::T::Boolean, options: ::T.untyped, blk: ::T.proc.returns(::T.untyped)).returns(::T.untyped) }
  def http_cache_forever(public: T.unsafe(nil), **options, &blk); end
end

module ActiveStorage
  # mattr_accessor from lib/rails_ext/active_storage_blob_service_url_for_direct_upload_expiry.rb
  sig { returns(ActiveSupport::Duration) }
  def self.service_urls_for_direct_uploads_expire_in; end

  sig { params(value: ActiveSupport::Duration).returns(ActiveSupport::Duration) }
  def self.service_urls_for_direct_uploads_expire_in=(value); end
end
