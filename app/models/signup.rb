class Signup
  # @rbs @tenant: Integer?

  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :full_name, :email_address #: String?
  attr_accessor :identity #: Identity?
  attr_accessor :skip_account_seeding #: boolish
  attr_reader :account #: Account?
  attr_reader :user #: User?

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, :identity, presence: true, on: :completion
  validates :full_name, length: { maximum: 240 }

  #: (?Hash[Symbol, untyped] attributes) -> void
  def initialize(...)
    # @type ivar @identity: Identity
    super

    @email_address = @identity.email_address if @identity
  end

  #: () -> MagicLink
  def create_identity
    # @type ivar @identity: Identity
    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link for: :sign_up
  end

  #: () -> bool
  def complete
    if valid?(:completion)
      begin
        @tenant = create_tenant
        create_account
        true
      rescue => error
        destroy_account
        handle_account_creation_error(error)

        errors.add(:base, "Something went wrong, and we couldn't create your account. Please give it another try.")
        Rails.error.report(error, severity: :error)
        Rails.logger.error error
        Rails.logger.error error.backtrace.join("\n")

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
      # @type ivar @account: Account
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
      identity = self.identity #: Identity
      full_name = self.full_name #: String
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
      subscription = FreeV1Subscription # steep:ignore UnknownConstant

      { name: subscription.to_param, price: subscription.price }
    end

    #: () -> Hash[Symbol, untyped]
    def request_attributes
      { remote_address: Current.ip_address, user_agent: Current.user_agent, referrer: Current.referrer }
    end
end
