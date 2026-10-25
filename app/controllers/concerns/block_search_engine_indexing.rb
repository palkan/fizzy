# Tell crawlers like Googlebot to drop pages entirely from search results, even
# if other sites link to it
module BlockSearchEngineIndexing
  # @type instance: ApplicationController
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationController)
    after_action :block_search_engine_indexing
  end

  private
    def block_search_engine_indexing
      headers["X-Robots-Tag"] = "none"
    end
end
