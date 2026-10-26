# typed: true

class Account::DataTransfer::ActiveStorage::AttachmentRecordSet < Account::DataTransfer::RecordSet
  #: (Account) -> void
  def initialize(account)
    super(account: account, model: ::ActiveStorage::Attachment)
  end

  private
    #: () -> ActiveRecord::Relation
    def records
      ::ActiveStorage::Attachment.where(account: account)
        .where.not(record_type: INTERNAL_RECORD_TYPES)
    end
end
