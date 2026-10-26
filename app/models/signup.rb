# typed: true

class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  #: String?
  attr_accessor :full_name, :email_address
  #: Identity?
  attr_accessor :identity
  #: BasicObject
  attr_accessor :skip_account_seeding
  #: Account?
  attr_reader :account
  #: User?
  attr_reader :user

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, :identity, presence: true, on: :completion
  validates :full_name, length: { maximum: 240 }

  def initialize(...)
    super

    @email_address = @identity.email_address if @identity
  end

  #: () -> MagicLink
  def create_identity
    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link for: :sign_up
  end

  #: () -> bool
  def complete
    if valid?(:completion)
      begin
        @tenant = create_tenant #: Integer?
        create_account
        true
      rescue => error
        destroy_account
        handle_account_creation_error(error)

        errors.add(:base, "Something went wrong, and we couldn't create your account. Please give it another try.")
        Rails.error.report(error, severity: :error)
        Rails.logger.error error
        # A rescued error was raised, so it has a backtrace.
        backtrace = error.backtrace #: as !nil
        Rails.logger.error backtrace.join("\n")

        false
      end
    else
      false
    end
  end

  private
    # Override to customize the handling of external accounts associated to the account.
    #: () -> Integer?
    def create_tenant
      nil
    end

    # Override to inject custom handling for account creation errors
    #: (StandardError error) -> void
    def handle_account_creation_error(error)
    end

    #: () -> void
    def create_account
      @account = Account.create_with_owner(
        account: {
          external_account_id: @tenant,
          name: generate_account_name
        },
        owner: {
          name: full_name,
          identity: identity
        }
      )
      @user = @account.users.find_by!(role: :owner)
      @account.setup_customer_template unless skip_account_seeding
    end

    #: () -> String
    def generate_account_name
      # Both are validated present on completion.
      identity = self.identity #: as !nil
      full_name = self.full_name #: as !nil
      AccountNameGenerator.new(identity: identity, name: full_name).generate
    end


    #: () -> void
    def destroy_account
      @account&.destroy!

      @user = nil
      @account = nil
      @tenant = nil
    end

    #: () -> Hash[Symbol, untyped]
    def subscription_attributes
      # FreeV1Subscription is defined by the SaaS engine
      subscription = FreeV1Subscription

      { name: subscription.to_param, price: subscription.price }
    end

    #: () -> Hash[Symbol, untyped]
    def request_attributes
      { remote_address: Current.ip_address, user_agent: Current.user_agent, referrer: Current.referrer }
    end
end
