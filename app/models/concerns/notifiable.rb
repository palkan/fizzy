# typed: true

# @requires_ancestor: ApplicationRecord
module Notifiable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationRecord)
    has_many :notifications, as: :source, dependent: :destroy

    after_create_commit :notify_recipients_later
  end

  #: () -> void
  def notify_recipients
    source = self #: as ApplicationRecord
    Notifier.for(source)&.notify
  end

  #: () -> ApplicationRecord
  def notifiable_target
    self #: as ApplicationRecord
  end

  private
    #: () -> void
    def notify_recipients_later
      notifiable = self #: as Event | Mention
      NotifyRecipientsJob.perform_later notifiable
    end
end
