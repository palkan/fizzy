class Export < ApplicationRecord
  belongs_to :account
  belongs_to :user

  has_one_attached :file, dependent: :purge_later

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending

  scope :current, -> { where(created_at: 24.hours.ago..) }
  scope :expired, -> { where(completed_at: ...24.hours.ago) }

  #: () -> void
  def self.cleanup
    expired.destroy_all
  end

  #: () -> void
  def build_later
    DataExportJob.perform_later(self)
  end

  #: () -> void
  def build
    processing!

    with_context do
      ZipFile.create_for(file, filename: filename) do |zip|
        populate_zip(zip)
      end
      mark_completed
      ExportMailer.completed(self).deliver_later
    end
  rescue => e
    update!(status: :failed)
    raise e
  end

  #: () -> void
  def mark_completed
    update!(status: :completed, completed_at: Time.current)
  end

  #: (User accessor) -> bool
  def accessible_to?(accessor)
    accessor == user
  end

  private
    #: () -> String
    def filename
      "fizzy-export-#{id}.zip"
    end

    #: () { () -> void } -> void
    def with_context
      Current.set(account: account) do
        old_url_options = ActiveStorage::Current.url_options
        ActiveStorage::Current.url_options = Rails.application.routes.default_url_options

        yield
      ensure
        ActiveStorage::Current.url_options = old_url_options
      end
    end

    #: (ZipFile::Writer zip) -> void
    def populate_zip(zip)
      raise NotImplementedError, "Subclasses must implement populate_zip"
    end
end
