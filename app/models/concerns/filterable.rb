module Filterable
  # @type instance: Filterable & Filterable::_Includer & ApplicationRecord
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationRecord)
    has_and_belongs_to_many :filters

    after_update do
      # @type self: Filterable & Filterable::_Includer & ApplicationRecord
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
