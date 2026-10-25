class Identity < ApplicationRecord
  # @rbs skip -- declared in sig/generated/inline.rbs
  include Joinable, Transferable

  has_passkeys name: :email_address, display_name: -> { Current.user&.name || email_address }

  has_many :access_tokens, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  has_one_attached :avatar, dependent: :purge_later

  before_destroy :deactivate_users, prepend: true

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }

  #: (String token, method: String) -> Identity?
  def self.find_by_permissable_access_token(token, method:)
    if (access_token = AccessToken.find_by(token: token)) && access_token.allows?(method)
      access_token.identity
    end
  end

  #: (**untyped attributes) -> MagicLink
  def send_magic_link(**attributes)
    attributes[:purpose] = attributes.delete(:for) if attributes.key?(:for)

    magic_links.create!(attributes).tap do |magic_link|
      MagicLinkMailer.sign_in_instructions(magic_link).deliver_later
    end
  end

  #: () -> User::ActiveRecord_Associations_CollectionProxy
  def users_with_active_accounts
    users.joins(:account).merge(Account.active).includes(:account)
  end

  private
    #: () -> void
    def deactivate_users
      users.find_each(&:deactivate)
    end
end
