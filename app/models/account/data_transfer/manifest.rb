# typed: true

class Account::DataTransfer::Manifest
  #: Account
  attr_reader :account

  #: (Account) -> void
  def initialize(account)
    @account = account
  end

  #: (?start: [ String, String ]?) ?{ (Account::DataTransfer::RecordSet, String?) -> void } -> void
  def each_record_set(start: nil, &block)
    raise ArgumentError, "No block given" unless block_given?

    started = start.nil? #: bool
    record_class, last_id = start if start

    record_sets.each do |record_set|
      if started
        yield record_set, nil
      elsif record_set.model.name == record_class
        started = true
        yield record_set, last_id
      end
    end
  end

  private
    #: () -> Array[Account::DataTransfer::RecordSet]
    def record_sets
      [
        Account::DataTransfer::AccountRecordSet.new(account),
        Account::DataTransfer::UserRecordSet.new(account),
        *record_sets_for(
          ::User::Settings,
          ::Tag,
          ::Board,
          ::Column
        ),
        Account::DataTransfer::EntropyRecordSet.new(account),
        *record_sets_for(
          ::Board::Publication,
          ::Webhook,
          ::Access,
          ::Card,
          ::Comment,
          ::Step,
          ::Assignment,
          ::Tagging,
          ::Closure,
          ::Card::Goldness,
          ::Card::NotNow,
          ::Card::ActivitySpike,
          ::Watch,
          ::Pin,
          ::Reaction,
          ::Mention,
          ::Filter,
          ::Webhook::DelinquencyTracker,
          ::Event,
          ::Notification,
          ::Notification::Bundle,
          ::Webhook::Delivery
        ),
        Account::DataTransfer::ActiveStorage::BlobRecordSet.new(account),
        record_set_for(::ActiveStorage::VariantRecord),
        Account::DataTransfer::ActiveStorage::AttachmentRecordSet.new(account),
        Account::DataTransfer::ActionText::RichTextRecordSet.new(account),
        Account::DataTransfer::ActiveStorage::FileRecordSet.new(account)
      ].then { set_importable_model_names(it) }
    end

    #: (*singleton(ActiveRecord::Base)) -> Array[Account::DataTransfer::RecordSet]
    def record_sets_for(*models)
      models.map do |model|
        record_set_for(model)
      end
    end

    #: (singleton(ActiveRecord::Base)) -> Account::DataTransfer::RecordSet
    def record_set_for(model)
      Account::DataTransfer::RecordSet.new(account: account, model: model)
    end

    #: (Array[Account::DataTransfer::RecordSet]) -> Array[Account::DataTransfer::RecordSet]
    def set_importable_model_names(record_sets)
      model_names = record_sets.filter_map { |record_set| record_set.model.name }
      record_sets.each { |record_set| record_set.importable_model_names = model_names }
      record_sets
    end
end
