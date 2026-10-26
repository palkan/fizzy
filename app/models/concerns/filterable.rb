# typed: true

# @requires_ancestor: ApplicationRecord
module Filterable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationRecord)
    has_and_belongs_to_many :filters

    after_update do
      #: self as Filterable
      filters.touch_all
    end
    before_destroy :remove_from_filters
  end

  private
    # FIXME: This is too inefficient to have part of a destroy transaction.
    # Need to find a way to use a job or a single query.
    #: () -> void
    def remove_from_filters
      filters.each { it.resource_removed self }
    end
end
