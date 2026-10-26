# typed: true

class Notification::Bundle < ApplicationRecord
  belongs_to :account, default: -> {
    #: self as Notification::Bundle
    user.account
  }
  belongs_to :user

  enum :status, %i[ pending processing delivered ]

  scope :due, -> { pending.where("ends_at <= ?", Time.current) }
  scope :containing, ->(notification) { where("starts_at <= ? AND ends_at > ?", notification.updated_at, notification.updated_at) }
  scope :overlapping_with, ->(other_bundle) do
    where(
      "(starts_at <= ? AND ends_at >= ?) OR (starts_at <= ? AND ends_at >= ?) OR (starts_at >= ? AND ends_at <= ?)",
      other_bundle.starts_at, other_bundle.starts_at,
      other_bundle.ends_at, other_bundle.ends_at,
      other_bundle.starts_at, other_bundle.ends_at
    )
  end

  before_validation :set_default_window, if: :new_record?

  validate :validate_no_overlapping

  #: () -> void
  def self.deliver_all
    due.in_batches do |batch|
      jobs = batch.collect { DeliverJob.new(it) }
      ActiveJob.perform_all_later jobs
    end
  end

  #: () -> void
  def self.deliver_all_later
    DeliverAllJob.perform_later
  end

  #: () -> Notification::PrivateAssociationRelation
  def notifications
    user.notifications.where(updated_at: window).unread
  end

  #: () -> void
  def deliver
    user.in_time_zone do
      Current.with_account(user.account) do
        processing!

        Notification::BundleMailer.notification(self).deliver if deliverable?

        delivered!
      end
    end
  end

  #: () -> void
  def deliver_later
    DeliverJob.perform_later(self)
  end

  #: () -> void
  def flush
    update!(ends_at: Time.current)
    deliver_later
  end

  #: () -> void
  def set_default_window
    # Bundles are only created for users with settings (not system users)
    settings = user.settings #: as !nil
    # Unset on new bundles
    starts_at = self.starts_at #: ActiveSupport::TimeWithZone?
    ends_at = self.ends_at #: ActiveSupport::TimeWithZone?

    self.starts_at = Time.current unless starts_at
    self.ends_at = self.starts_at + settings.bundle_aggregation_period unless ends_at
  end

  private
    def window
      starts_at..ends_at
    end

    def validate_no_overlapping
      if overlapping_bundles.exists?
        errors.add(:base, "Bundle window overlaps with an existing pending bundle with id #{overlapping_bundles.first.id}")
      end
    end

    def deliverable?
      settings = user.settings #: as !nil
      settings.bundling_emails? && notifications.any? && account.active?
    end

    def overlapping_bundles
      user.notification_bundles.where.not(id: id).overlapping_with(self)
    end
end
