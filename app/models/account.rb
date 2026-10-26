# typed: true

class Account < ApplicationRecord
  include Account::Storage, Cancellable, Entropic, Incineratable, MultiTenantable, Searchable, Seedeable

  has_one :join_code, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :entropies, dependent: :destroy
  has_many :exports, class_name: "Account::Export", dependent: :destroy
  has_many :imports, class_name: "Account::Import", dependent: :destroy

  scope :importing, -> { left_joins(:imports).where(account_imports: { status: %i[pending processing failed] }) }
  scope :active, -> { where.missing(:cancellation).and(where.not(id: importing)) }

  before_create :assign_external_account_id
  after_create :create_join_code

  validates :name, presence: true

  #: (account: Hash[Symbol, untyped], owner: Hash[Symbol, untyped]) -> Account
  def self.create_with_owner(account:, owner:)
    create!(**account).tap do |account|
      account.users.create!(role: :system, name: "System")
      account.users.create!(owner.with_defaults(role: :owner, verified_at: Time.current))
    end
  end

  #: () -> String
  def slug
    # Assigned before create; a slug is only built for persisted accounts.
    external_account_id = self.external_account_id #: as !nil
    "/#{AccountSlug.encode(external_account_id)}"
  end

  #: () -> Account
  def account
    self
  end

  #: () -> User
  def system_user
    users.find_by!(role: :system)
  end

  #: () -> bool
  def active?
    !cancelled? && !importing?
  end

  #: () -> bool
  def importing?
    imports.where(status: %i[pending processing failed]).exists?
  end

  private
    #: () -> void
    def assign_external_account_id
      self.external_account_id ||= ExternalIdSequence.next
    end
end
