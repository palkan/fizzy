# typed: true

# Converted from sig/shims/search.rbs

class Search::Record
  include Search::Record::SQLite
  include Search::Record::Trilogy
  extend Search::Record::SQLite::ClassMethods
  extend Search::Record::Trilogy::ClassMethods

  sig { returns(::T.nilable(String)) }
  def result_title; end

  sig { returns(::T.nilable(String)) }
  def result_content; end
end

class Search::Result
  sig { returns(::T.nilable(String)) }
  def card_id; end

  sig { returns(::T.nilable(Card)) }
  def card; end

  sig { returns(::T.nilable(String)) }
  def comment_id; end

  sig { returns(::T.nilable(Comment)) }
  def comment; end

  sig { returns(::T.nilable(String)) }
  def creator_id; end

  sig { returns(User) }
  def creator; end

  sig { returns(String) }
  def query; end
end

class Search::Record
  sig { returns(String) }
  def query; end
end

class Search::Record::PrivateRelation
  sig { params(query: Search::Query).returns(::T::Array[String]) }
  def search_fields(query); end
end

class Search::Record
  sig { returns(::T.nilable(String)) }
  def account_key; end

  sig { params(arg0: ::T.nilable(String)).returns(::T.nilable(String)) }
  def account_key=(arg0); end
end

