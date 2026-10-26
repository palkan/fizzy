# typed: true

class Mention < ApplicationRecord
  include Notifiable

  belongs_to :account, default: -> {
    #: self as Mention
    source.account
  }
  belongs_to :source, polymorphic: true
  belongs_to :mentioner, class_name: "User"
  belongs_to :mentionee, class_name: "User", inverse_of: :mentions

  after_create_commit :watch_source_by_mentionee

  delegate :card, to: :source

  #: () -> bool
  def self_mention?
    mentioner == mentionee
  end

  #: () -> ApplicationRecord
  def notifiable_target
    source
  end

  private
    #: () -> void
    def watch_source_by_mentionee
      source.watch_by(mentionee)
    end
end
