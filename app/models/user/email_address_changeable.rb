# typed: true

# @requires_ancestor: User
module User::EmailAddressChangeable
  EMAIL_CHANGE_TOKEN_PURPOSE = "change_email_address"
  EMAIL_CHANGE_TOKEN_EXPIRATION = 30.minutes

  extend ActiveSupport::Concern

  #: (String) -> bool
  def change_email_address_using_token(token)
    parsed_token = SignedGlobalID.parse(token, for: EMAIL_CHANGE_TOKEN_PURPOSE)

    old_email_address = parsed_token&.params&.fetch("old_email_address")
    new_email_address = parsed_token&.params&.fetch("new_email_address")

    if parsed_token.nil? || parsed_token.find != self || current_email_address != old_email_address
      false
    else
      change_email_address(new_email_address)
    end
  end

  #: (String) -> void
  def send_email_address_change_confirmation(new_email_address)
    token = generate_email_address_change_token(
      to: new_email_address,
      expires_in: EMAIL_CHANGE_TOKEN_EXPIRATION
    )

    UserMailer.email_change_confirmation(
      email_address: new_email_address,
      token: token,
      user: self #: as User
    ).deliver_later
  end

  #: (String) -> bool
  def change_email_address(new_email_address)
    transaction do
      new_identity = Identity.find_or_create_by!(email_address: new_email_address)
      update!(identity: new_identity)
    end
  end

  private
    #: (to: String, ?from: String, **untyped) -> String
    def generate_email_address_change_token(to:, from: current_email_address, **options)
      options = options.with_defaults(
        for: EMAIL_CHANGE_TOKEN_PURPOSE,
        old_email_address: from,
        new_email_address: to,
      )

      to_sgid(**options).to_s
    end

    #: () -> String
    def current_email_address
      # Deactivated users lose their identity, but they can't change their email address
      identity = self.identity #: as !nil
      identity.email_address
    end
end
