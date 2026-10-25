class DeleteUnusedTagsJob < ApplicationJob
  #: () -> void
  def perform
    Tag.unused.find_each do |tag|
      tag.destroy!
    end
  end
end
