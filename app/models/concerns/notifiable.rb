module Notifiable
  # @type instance: Notifiable & ApplicationRecord
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationRecord)
    has_many :notifications, as: :source, dependent: :destroy

    after_create_commit :notify_recipients_later
  end

  #: () -> void
  def notify_recipients
    Notifier.for(self)&.notify
  end

  #: () -> ApplicationRecord
  def notifiable_target
    self
  end

  private
    #: () -> void
    def notify_recipients_later
      NotifyRecipientsJob.perform_later self
    end
end
