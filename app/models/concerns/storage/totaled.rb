# typed: true

# @requires_ancestor: ApplicationRecord
module Storage::Totaled
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationRecord) & Storage::Totaled::ClassMethods
    has_one :storage_total, as: :owner, class_name: "Storage::Total", dependent: :destroy
    has_many :storage_entries, class_name: "Storage::Entry", foreign_key: foreign_key_for_storage
  end

  # Not `requires_ancestor`: Account::Storage and Board::Storage are concerns that include this one
  module ClassMethods
    #: () -> String
    def foreign_key_for_storage
      #: self as singleton(ApplicationRecord)
      "#{model_name.singular}_id"
    end
  end

  # Fast: materialized snapshot (may be slightly stale)
  #: () -> Integer
  def bytes_used
    storage_total&.bytes_stored || 0
  end

  # Exact: snapshot + pending entries
  #: () -> Integer
  def bytes_used_exact
    create_or_find_storage_total.current_usage
  end

  #: () -> void
  def materialize_storage_later
    owner = self #: as Account | Board
    Storage::MaterializeJob.perform_later(owner)
  end

  # Materialize all pending entries into snapshot
  #: () -> void
  def materialize_storage
    total = create_or_find_storage_total

    total.with_lock do
      latest_entry_id = storage_entries.maximum(:id)

      if latest_entry_id && total.last_entry_id != latest_entry_id
        scope = storage_entries.where(id: ..latest_entry_id)
        scope = scope.where.not(id: ..total.last_entry_id) if total.last_entry_id
        delta_sum = scope.sum(:delta)

        total.update! bytes_stored: total.bytes_stored + delta_sum, last_entry_id: latest_entry_id
      end
    end
  end

  # Reconcile ledger against actual attachment storage.
  #
  # Uses two-cursor approach for consistency: capture cursor before AND after the
  # scan. If they differ, entries were added during the scan and we can't get an
  # accurate diff without risking double-counting or undercounting.
  #
  # Returns true if reconciled successfully, false if aborted due to concurrent
  # writes. Caller (ReconcileJob) handles retries to avoid amplification.
  #: () -> bool
  def reconcile_storage
    cursor_before = storage_entries.maximum(:id)
    real_bytes = calculate_real_storage_bytes
    cursor_after = storage_entries.maximum(:id)

    if cursor_before != cursor_after
      Rails.logger.warn "[Storage] Reconcile aborted for #{self.class}##{id}: cursor moved during scan"
      false
    else
      ledger_bytes = cursor_after ? storage_entries.where(id: ..cursor_after).sum(:delta) : 0 #: as Integer
      diff = real_bytes - ledger_bytes

      if diff.nonzero?
        Rails.logger.info "[Storage] Reconcile #{self.class}##{id}: adjusting by #{diff} bytes"
        Storage::Entry.record \
          account: is_a?(Account) ? self : account, #: Account
          board: is_a?(Board) ? self : nil, #: Board?
          recordable: nil,
          delta: diff,
          operation: "reconcile"
      end

      true
    end
  end

  private
    #: () -> Storage::Total
    def create_or_find_storage_total
      self.storage_total ||= Storage::Total.create_or_find_by!(owner: self)
    end

    #: () -> Integer
    def calculate_real_storage_bytes
      raise NotImplementedError, "Subclass must implement calculate_real_storage_bytes"
    end
end
