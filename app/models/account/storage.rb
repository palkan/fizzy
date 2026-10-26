# typed: true

# @requires_ancestor: Account
module Account::Storage
  extend ActiveSupport::Concern
  include ::Storage::Totaled

  included do
    #: self as singleton(Account)
    before_destroy :clear_storage_entries
  end

  private
    def clear_storage_entries
      ::Storage::Entry.where(account_id: id).delete_all
    end

    def calculate_real_storage_bytes
      boards.sum { |board| board.send(:calculate_real_storage_bytes) }
    end
end
