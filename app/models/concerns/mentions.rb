# typed: true

# @requires_ancestor: ApplicationRecord
module Mentions
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationRecord)
    has_many :mentions, as: :source, dependent: :destroy
    has_many :mentionees, through: :mentions
    after_save_commit :create_mentions_later, if: :should_create_mentions?
  end

  #: (?mentioner: User?) -> void
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
    mentionees_from_attachments & mentionable_users.to_a
  end

  private
    #: () -> Array[untyped]
    def mentionees_from_attachments
      rich_text_associations.flat_map { send(it.name)&.body&.attachments&.collect { it.attachable } }.compact
    end

    #: () -> User::PrivateCollectionProxy
    def mentionable_users
      board.users
    end

    #: () -> Array[untyped]
    def rich_text_associations
      model = self.class #: as singleton(ApplicationRecord)
      model.reflect_on_all_associations(:has_one).filter { it.klass == ActionText::RichText }
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
      record = self #: as Card | Comment
      # Mentions are created when a signed-in user saves the record.
      mentioner = Current.user #: as !nil
      Mention::CreateJob.perform_later(record, mentioner:)
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
