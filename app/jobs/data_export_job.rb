# typed: true

class DataExportJob < ApplicationJob
  queue_as :backend

  discard_on ActiveJob::DeserializationError

  #: (Export) -> void
  def perform(export)
    export.build
  end
end
