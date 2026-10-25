module Mentions
  # @type instance: Mentions & Mentions::_Includer & ApplicationRecord
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationRecord)
    has_many :mentions, as: :source, dependent: :destroy
    has_many :mentionees, through: :mentions
    after_save_commit :create_mentions_later, if: :should_create_mentions?
  end

  #: (?mentioner: User) -> void
  def create_mentions(mentioner: Current.user)
    scan_mentionees.each do |mentionee|
      mentionee.mentioned_by mentioner, at: self
    end
  end

  #: () -> String
  def mentionable_content
    rich_text_associations.collect { send(it.name)&.to_plain_text }.compact.join(" ")
  end

  #: () -> Array[User]
  def scan_mentionees
    mentionees_from_attachments & mentionable_users
  end

  private
    #: () -> Array[untyped]
    def mentionees_from_attachments
      rich_text_associations.flat_map { send(it.name)&.body&.attachments&.collect { it.attachable } }.compact
    end

    #: () -> User::ActiveRecord_Associations_CollectionProxy
    def mentionable_users
      board.users
    end

    #: () -> Array[untyped]
    def rich_text_associations
      self.class.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::RichText }
    end

    #: () -> bool
    def should_create_mentions?
      mentionable? && (mentionable_content_changed? || should_check_mentions?)
    end

    #: () -> bool
    def mentionable_content_changed?
      rich_text_associations.any? { send(it.name)&.body_previously_changed? }
    end

    #: () -> void
    def create_mentions_later
      Mention::CreateJob.perform_later(self, mentioner: Current.user)
    end

    # Template method
    #: () -> bool
    def mentionable?
      true
    end

    #: () -> bool
    def should_check_mentions?
      false
    end
end
