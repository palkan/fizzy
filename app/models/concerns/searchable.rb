module Searchable
  # @type instance: Searchable & Searchable::_Includer & ApplicationRecord
  extend ActiveSupport::Concern

  SEARCH_CONTENT_LIMIT = 32.kilobytes

  included do
    # @type self: singleton(ApplicationRecord)
    after_create_commit :create_in_search_index
    after_update_commit :update_in_search_index
    after_destroy_commit :remove_from_search_index
  end

  #: () -> void
  def reindex
    update_in_search_index
  end

  private
    #: () -> void
    def create_in_search_index
      if searchable?
        search_record_class.create!(search_record_attributes)
      end
    end

    #: () -> void
    def update_in_search_index
      if searchable?
        search_record_class.upsert!(search_record_attributes)
      else
        remove_from_search_index
      end
    end

    #: () -> void
    def remove_from_search_index
      search_record_class.find_by(searchable_type: self.class.name, searchable_id: id)&.destroy
    end

    #: () -> Hash[Symbol, untyped]
    def search_record_attributes
      {
        account_id: account_id,
        searchable_type: self.class.name,
        searchable_id: id,
        card_id: search_card_id,
        board_id: search_board_id,
        title: search_title,
        content: search_record_content,
        created_at: created_at
      }
    end

    #: () -> String?
    def search_record_content
      search_content&.truncate_bytes(SEARCH_CONTENT_LIMIT, omission: "")
    end

    #: () -> singleton(Search::Record)
    def search_record_class
      Search::Record.for(account_id)
    end

  # Models must implement these methods (see Searchable::_Includer in sig/shims/models_core.rbs):
  # - account_id: returns the account id
  # - search_title: returns title string or nil
  # - search_content: returns content string
  # - search_card_id: returns the card id (self.id for cards, card_id for comments)
  # - search_board_id: returns the board id
  # - searchable?: returns whether this record should be indexed
end
