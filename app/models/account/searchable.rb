module Account::Searchable
  # @type instance: Account
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Account)
    has_many :search_queries, class_name: "Search::Query", dependent: :delete_all

    before_destroy :clear_search_records
  end

  private
    def clear_search_records
      Search::Record.for(id).where(account_id: id).destroy_all
    end
end
