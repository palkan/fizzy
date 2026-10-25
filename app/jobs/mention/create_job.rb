class Mention::CreateJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  #: (Card | Comment, mentioner: User) -> void
  def perform(record, mentioner:)
    record.create_mentions(mentioner:)
  end
end
