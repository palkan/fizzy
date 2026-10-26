# typed: true

# Provides sequential IDs for +external_account_id+ when creating accounts without one.
class Account::ExternalIdSequence < ApplicationRecord
  #: () -> Integer
  def self.next
    with_lock do |sequence|
      sequence.increment!(:value).value
    end
  end

  #: () -> Integer
  def self.value
    first&.value || self.next
  end

  #: [T] () { (Account::ExternalIdSequence) -> T } -> T
  private_class_method def self.with_lock(&block)
    transaction do
      sequence = lock.first_or_create!(value: initial_value)
      yield sequence
    end
  end

  #: () -> Integer
  private_class_method def self.initial_value
    Account.maximum(:external_account_id) || 0
  end
end
