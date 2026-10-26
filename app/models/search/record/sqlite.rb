# typed: true

# @requires_ancestor: Search::Record
module Search::Record::SQLite
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Search::Record)
    attribute :result_title, :string
    attribute :result_content, :string

    has_one :search_records_fts, -> {
      # Association scopes run on the target's relation
      #: self as Search::Record::SQLite::Fts::PrivateRelation
      with_rowid
    },
      class_name: "Search::Record::SQLite::Fts", foreign_key: :rowid, primary_key: :id, dependent: :destroy

    after_save :upsert_to_fts5_table

    scope :matching, ->(query, account_id) {
      joins("INNER JOIN search_records_fts ON search_records_fts.rowid = #{table_name}.id")
        .where("search_records_fts MATCH ?", query)
    }
  end

  # @requires_ancestor: singleton(Search::Record)
  module ClassMethods
    #: (Search::Query) -> Array[String]
    def search_fields(query)
      opening_mark = connection.quote(Search::Highlighter::OPENING_MARK)
      closing_mark = connection.quote(Search::Highlighter::CLOSING_MARK)
      ellipsis = connection.quote(Search::Highlighter::ELIPSIS)

      [ "highlight(search_records_fts, 0, #{opening_mark}, #{closing_mark}) AS result_title",
        "snippet(search_records_fts, 1, #{opening_mark}, #{closing_mark}, #{ellipsis}, 20) AS result_content",
        "#{connection.quote(query.terms)} AS query" ]
    end

    #: (String) -> singleton(Search::Record)
    def for(account_id)
      self #: as singleton(Search::Record)
    end
  end

  #: () -> ActiveSupport::SafeBuffer?
  def card_title
    escape_fts_highlight(result_title || card.title)
  end

  #: () -> ActiveSupport::SafeBuffer?
  def card_description
    escape_fts_highlight(result_content) unless comment
  end

  #: () -> ActiveSupport::SafeBuffer?
  def comment_body
    escape_fts_highlight(result_content) if comment
  end

  private
    #: (String?) -> ActiveSupport::SafeBuffer?
    def escape_fts_highlight(html)
      return nil unless html.present?

      CGI.escapeHTML(html)
        .gsub(CGI.escapeHTML(Search::Highlighter::OPENING_MARK), Search::Highlighter::OPENING_MARK)
        .gsub(CGI.escapeHTML(Search::Highlighter::CLOSING_MARK), Search::Highlighter::CLOSING_MARK)
        .html_safe
    end

    def upsert_to_fts5_table
      Fts.upsert(id, title, content)
    end
end
