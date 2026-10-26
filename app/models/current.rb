# typed: true

class Current < ActiveSupport::CurrentAttributes
  attribute :session #: Session?
  attribute :user #: User?
  attribute :identity #: Identity?
  attribute :account #: Account?
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer #: String?

  #: (Session?) -> void
  def session=(value)
    super(value)

    if value.present?
      self.identity = value.identity
    end
  end

  #: (Identity?) -> void
  def identity=(identity)
    super(identity)

    if identity.present?
      self.user = identity.users.find_by(account: account)
    end
  end

  # The bang readers are for code that only runs once the attribute is set, such as
  # controller actions behind authentication. They raise instead of returning nil.

  #: () -> Session
  def session!
    session or raise_unset(:session)
  end

  #: () -> User
  def user!
    user or raise_unset(:user)
  end

  #: () -> Identity
  def identity!
    identity or raise_unset(:identity)
  end

  #: () -> Account
  def account!
    account or raise_unset(:account)
  end

  #: [T] (Account? value) { () -> T } -> T
  def with_account(value, &)
    with(account: value, &)
  end

  #: [T] () { () -> T } -> T
  def without_account(&)
    with(account: nil, &)
  end

  private
    #: (Symbol) -> bot
    def raise_unset(attribute)
      raise "Current.#{attribute} isn't set"
    end
end
