# typed: true

# Gaps in the Rails RBIs that Tapioca generates and that rbi-central annotates

class Rails::Application::Configuration
  # Configured in lib/action_pack/railtie.rb
  sig { returns(ActionPack::Configuration) }
  def action_pack; end

  sig { params(value: ActiveSupport::OrderedOptions).returns(ActiveSupport::OrderedOptions) }
  def action_pack=(value); end

  sig { returns(ActionMailer::Configuration) }
  def action_mailer; end
end

# The ActiveSupport::OrderedOptions behind `config.action_mailer`, which defines its keys dynamically
class ActionMailer::Configuration
  sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
  def default_url_options; end
end

# The ActiveSupport::OrderedOptions behind `config.action_pack`, set up in lib/action_pack/railtie.rb
class ActionPack::Configuration
  sig { returns(ActionPack::Configuration::WebAuthn) }
  def web_authn; end

  sig { params(value: ActiveSupport::OrderedOptions).returns(ActiveSupport::OrderedOptions) }
  def web_authn=(value); end

  sig { returns(ActionPack::Configuration::Passkey) }
  def passkey; end

  sig { params(value: ActiveSupport::OrderedOptions).returns(ActiveSupport::OrderedOptions) }
  def passkey=(value); end

  class WebAuthn
    sig { returns(T::Hash[Symbol, T.untyped]) }
    def default_request_options; end

    sig { params(value: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    def default_request_options=(value); end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def default_creation_options; end

    sig { params(value: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    def default_creation_options=(value); end

    sig { returns(ActiveSupport::Duration) }
    def creation_challenge_expiration; end

    sig { params(value: ActiveSupport::Duration).returns(ActiveSupport::Duration) }
    def creation_challenge_expiration=(value); end

    sig { returns(ActiveSupport::Duration) }
    def request_challenge_expiration; end

    sig { params(value: ActiveSupport::Duration).returns(ActiveSupport::Duration) }
    def request_challenge_expiration=(value); end
  end

  class Passkey
    sig { returns(String) }
    def parent_class_name; end

    sig { params(value: String).returns(String) }
    def parent_class_name=(value); end

    sig { returns(String) }
    def routes_prefix; end

    sig { params(value: String).returns(String) }
    def routes_prefix=(value); end

    sig { returns(T::Boolean) }
    def draw_routes; end

    sig { params(value: T::Boolean).returns(T::Boolean) }
    def draw_routes=(value); end

    # Evaluated in the view with instance_exec
    sig { returns(T.nilable(T.proc.returns(String))) }
    def challenge_url; end

    sig { params(value: T.nilable(T.proc.returns(String))).returns(T.untyped) }
    def challenge_url=(value); end
  end
end

class ActiveStorage::Attached::One
  # Delegated to the attachment
  sig { returns(T.nilable(ActiveStorage::Blob)) }
  def blob; end

  sig { returns(T.nilable(ActiveStorage::Attachment)) }
  def attachment; end

  sig { params(transformations: T.untyped).returns(T.untyped) }
  def variant(transformations); end

  sig { returns(T::Boolean) }
  def variable?; end

  sig { returns(T.nilable(String)) }
  def content_type; end

  sig { returns(T.nilable(ActiveStorage::Filename)) }
  def filename; end

  sig { returns(T.nilable(Integer)) }
  def byte_size; end
end

class ActiveStorage::Attached::Many
  # Delegated to the attachments
  sig { returns(T::Boolean) }
  def any?; end

  sig { returns(T::Array[ActiveStorage::Attachment]) }
  def to_a; end
end

class ActionMailer::Base
  include GeneratedUrlHelpersModule
end

class ActionMailer::MessageDelivery
  # Delegated to the Mail::Message
  sig { returns(Mail::Message) }
  def deliver; end
end

module ActionController::RequestForgeryProtection
  private

  # Newer than the actionpack RBI annotations
  sig { returns(T::Boolean) }
  def verified_via_header_only?; end

  sig { returns(T.nilable(String)) }
  def sec_fetch_site_value; end
end

class ActiveRecord::Relation
  # Query internals used by lib/rails_ext/active_record_optimizer_hints.rb and lib/rails_ext/prepend_order.rb
  sig { returns(T::Array[String]) }
  def optimizer_hints_values; end

  sig { returns(T::Array[T.untyped]) }
  def order_values; end

  sig { params(value: T::Array[T.untyped]).returns(T::Array[T.untyped]) }
  def order_values=(value); end

  sig { returns(String) }
  def quoted_table_name; end
end

# Route proxy for the application from engines and mounted apps
class ActionController::Base
  sig { returns(T.untyped) }
  def main_app; end
end

class ActionView::Base
  sig { returns(T.untyped) }
  def main_app; end
end

class ActiveSupport::TimeWithZone
  # Delegated to the time, missing from the gem RBI
  sig { returns(ActiveSupport::TimeWithZone) }
  def beginning_of_day; end
end
