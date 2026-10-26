# typed: true

# @requires_ancestor: Search::Record
module Search::Record::Trilogy
  extend ActiveSupport::Concern

  SHARD_COUNT = 16

  included do
    #: self as singleton(Search::Record)
    self.abstract_class = true
    before_save :set_account_key, :stem_content

    scope :matching, ->(query, account_id) do
      full_query = "+account#{account_id} +(#{Search::Stemmer.stem(query)})"
      where("MATCH(#{table_name}.account_key, #{table_name}.content, #{table_name}.title) AGAINST(? IN BOOLEAN MODE)", full_query)
    end

    SHARD_CLASSES = SHARD_COUNT.times.map do |shard_id|
      Class.new(self) do
        #: self as singleton(Search::Record)
        self.table_name = "search_records_#{shard_id}"

        def self.name
          "Search::Record"
        end
      end
    end.freeze
  end

  # @requires_ancestor: singleton(Search::Record)
  module ClassMethods
    #: (String) -> Integer
    def shard_id_for_account(account_id)
      Zlib.crc32(account_id.to_s) % SHARD_COUNT
    end

    #: (Search::Query) -> Array[String]
    def search_fields(query)
      [ "#{connection.quote(query.terms)} AS query" ]
    end

    #: (String) -> singleton(Search::Record)
    def for(account_id)
      SHARD_CLASSES[shard_id_for_account(account_id)]
    end
  end

  #: () -> String?
  def card_title
    highlight(card.title, show: :full) if card_id
  end

  #: () -> String?
  def card_description
    highlight(card.description.to_plain_text, show: :snippet) if card_id
  end

  #: () -> String?
  def comment_body
    if comment = self.comment
      highlight(comment.body.to_plain_text, show: :snippet)
    end
  end

  private
    def stem_content
      self.title = Search::Stemmer.stem(title) if title_changed?
      self.content = Search::Stemmer.stem(content) if content_changed?
    end

    def set_account_key
      self.account_key = "account#{account_id}"
    end

    #: (String?, show: Symbol) -> String?
    def highlight(text, show:)
      if text.present? && attribute?(:query)
        highlighter = Search::Highlighter.new(query)
        show == :snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      else
        text
      end
    end
end
