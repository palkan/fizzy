# typed: true

# Adds passkey support to an Active Record model (the "holder" of passkeys).
#
# == Usage
#
#   class User < ApplicationRecord
#     has_passkeys name: :email_address, display_name: :name
#   end
#
# This sets up a polymorphic +has_many :passkeys+ association and defines two methods on the
# model that supply holder-specific options for the WebAuthn ceremonies:
#
# - +passkey_registration_options+ — merged into ActionPack::Passkey.registration_options
# - +passkey_authentication_options+ — merged into ActionPack::Passkey.authentication_options
#
# == Options
#
# +has_passkeys+ accepts keyword arguments that map to WebAuthn creation or request option
# fields. Values can be symbols (sent to the record), procs (evaluated in the record's context),
# or plain values:
#
# [+name+]
#   A human-readable account identifier (typically an email or username) shown by the
#   authenticator when the user selects a passkey. Maps to the WebAuthn +user.name+ field.
#
# [+display_name+]
#   A friendly label for the user (typically their full name) shown by the authenticator
#   during passkey registration. Maps to the WebAuthn +user.displayName+ field.
#
#   has_passkeys name: :email, display_name: :name
#
# For more complex configuration, pass a block that receives a ActionPack::Passkey::Holder::Config:
#
#   has_passkeys do |config|
#     config.registration_options { { name: email, display_name: name } }
#     config.authentication_options { { user_verification: "required" } }
#   end
# @requires_ancestor: ActiveRecord::Base
module ActionPack::Passkey::Holder
  extend ActiveSupport::Concern

  # @requires_ancestor: singleton(ActiveRecord::Base)
  module ClassMethods
    # Declares that this model can hold passkeys. Sets up a polymorphic +has_many+ association
    # and defines +passkey_registration_options+ and +passkey_authentication_options+ instance methods used
    # by ActionPack::Passkey to build ceremony options.
    #
    # Keyword arguments matching CreationOptions or RequestOptions fields are extracted and
    # turned into holder-scoped option procs automatically. An optional block yields a Config
    # for more complex setup.
    #: (**untyped) ?{ (ActionPack::Passkey::Holder::Config) -> void } -> void
    def has_passkeys(**options, &block)
      config = Config.new(**options)
      block&.call(config)

      has_many config.association_name,
        as: :holder,
        dependent: config.dependent,
        class_name: "ActionPack::Passkey"

      define_method(:passkey_registration_options) do
        #: self as ActiveRecord::Base
        {
          id: id,
          exclude_credentials: public_send(config.association_name)
        }.merge(config.evaluate_registration_options(self))
      end

      define_method(:passkey_authentication_options) do
        #: self as ActiveRecord::Base
        { credentials: public_send(config.association_name) }.merge(config.evaluate_authentication_options(self))
      end
    end
  end

  # Configuration object yielded by +has_passkeys+ when a block is given. Allows setting
  # custom association options and ceremony option blocks.
  class Config
    #: Symbol
    attr_accessor :association_name
    #: Symbol
    attr_accessor :dependent

    #: (**untyped) -> void
    def initialize(**options)
      @association_name = options.delete(:association_name) || :passkeys
      @dependent = options.delete(:dependent) || :destroy

      if creation_opts = extract_options_for(ActionPack::WebAuthn::PublicKeyCredential::CreationOptions, options)
        @registration_options = options_to_proc(creation_opts)
      end

      if request_opts = extract_options_for(ActionPack::WebAuthn::PublicKeyCredential::RequestOptions, options)
        @authentication_options = options_to_proc(request_opts)
      end
    end

    # Sets a block to evaluate in the holder's context to produce additional authentication options.
    #
    #   config.authentication_options { { user_verification: "required" } }
    #: () { () [self: ActiveRecord::Base] -> Hash[Symbol, untyped] } -> void
    def authentication_options(&block)
      @authentication_options = block
    end

    # Sets a block to evaluate in the holder's context to produce additional creation options.
    #
    #   config.registration_options { { name: email, display_name: name } }
    #: () { () [self: ActiveRecord::Base] -> Hash[Symbol, untyped] } -> void
    def registration_options(&block)
      @registration_options = block
    end

    # Evaluates the request options block (if any) in the context of the given +record+. Called
    # internally by the +passkey_authentication_options+ method defined on the holder.
    #: (ActiveRecord::Base) -> Hash[Symbol, untyped]
    def evaluate_authentication_options(record)
      if options = @authentication_options
        record.instance_exec(&options)
      else
        {}
      end
    end

    # Evaluates the creation options block (if any) in the context of the given +record+. Called
    # internally by the +passkey_registration_options+ method defined on the holder.
    #: (ActiveRecord::Base) -> Hash[Symbol, untyped]
    def evaluate_registration_options(record)
      if options = @registration_options
        record.instance_exec(&options)
      else
        {}
      end
    end

    private
      #: (singleton(ActionPack::WebAuthn::PublicKeyCredential::Options), Hash[Symbol, untyped]) -> Hash[Symbol, untyped]?
      def extract_options_for(klass, options)
        keys = klass.attribute_names.map(&:to_sym)

        extracted = options.select { |key, _| keys.include?(key) }
        options.reject! { |key, _| keys.include?(key) }
        extracted if extracted.any?
      end

      #: (Hash[Symbol, untyped]) -> ^() -> Hash[Symbol, untyped]
      def options_to_proc(options)
        proc do
          #: self as ActiveRecord::Base
          options.transform_values do |value|
            case value
            when Symbol then send(value)
            when Proc then instance_exec(&value)
            else value
            end
          end
        end
      end
  end
end
