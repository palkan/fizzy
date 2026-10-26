# typed: true

# Converted from sig/shims/models.rbs

module Searchable
  # Provided by the including record
  sig { returns(String) }
  def account_id; end

  sig { returns(ActiveSupport::TimeWithZone) }
  def created_at; end

  sig { returns(::T.nilable(String)) }
  def search_title; end

  sig { returns(::T.nilable(String)) }
  def search_content; end

  sig { returns(String) }
  def search_card_id; end

  sig { returns(String) }
  def search_board_id; end

  sig { returns(::T::Boolean) }
  def searchable?; end
end

module Mentions
  # Provided by the including record
  sig { returns(Board) }
  def board; end
end

module Eventable
  # Provided by the including record
  sig { returns(Board) }
  def board; end
end

module Filterable
  # Provided by the including record
  sig { returns(Filter::PrivateCollectionProxy) }
  def filters; end
end

module Storage::Totaled
  # Provided by the including record
  sig { returns(::T.nilable(Storage::Total)) }
  def storage_total; end

  sig { params(arg0: ::T.nilable(Storage::Total)).returns(::T.nilable(Storage::Total)) }
  def storage_total=(arg0); end

  sig { returns(Storage::Entry::PrivateCollectionProxy) }
  def storage_entries; end

  sig { returns(Account) }
  def account; end
end

module Storage::Tracked
  # Provided by the including record
  sig { returns(Account) }
  def account; end

  sig { returns(Board) }
  def board; end
end

class Notifier
  private

  sig { returns(::T::Enumerable[User]) }
  def recipients; end

  sig { returns(User) }
  def creator; end
end

class Notifier
  module EventSource
    interface!

    sig { abstract.returns(Event) }
    def source; end
  end

  module MentionSource
    interface!

    sig { abstract.returns(Mention) }
    def source; end

    sig { abstract.returns(Mention) }
    def mention; end
  end
end

class Board
  module AccessesExtension
    interface!

    sig { abstract.params(granted: ::T::Enumerable[User], revoked: ::T::Enumerable[User]).void }
    def revise(granted: T.unsafe(nil), revoked: T.unsafe(nil)); end

    sig { abstract.params(arg0: ::T.any(User, ::T::Enumerable[User])).void }
    def grant_to(arg0); end

    sig { abstract.params(arg0: ::T.any(User, ::T::Enumerable[User])).void }
    def revoke_from(arg0); end
  end

  sig { returns(::T.all(::Access::PrivateCollectionProxy, Board::AccessesExtension)) }
  def accesses; end
end

class Filter
  module IndexedBy
    interface!

    sig { abstract.returns(::T::Boolean) }
    def all?; end

    sig { abstract.returns(::T::Boolean) }
    def closed?; end

    sig { abstract.returns(::T::Boolean) }
    def not_now?; end

    sig { abstract.returns(::T::Boolean) }
    def stalled?; end

    sig { abstract.returns(::T::Boolean) }
    def postponing_soon?; end

    sig { abstract.returns(::T::Boolean) }
    def golden?; end
  end

  module SortedBy
    interface!

    sig { abstract.returns(::T::Boolean) }
    def newest?; end

    sig { abstract.returns(::T::Boolean) }
    def oldest?; end

    sig { abstract.returns(::T::Boolean) }
    def latest?; end
  end

  module AssignmentStatus
    interface!

    sig { abstract.returns(::T::Boolean) }
    def unassigned?; end
  end

  # Filter::Fields overrides these store accessors inside its `included` block,
  # which Sorbet attributes to the concern rather than to Filter itself.
  sig { returns(::T.all(ActiveSupport::StringInquirer, Filter::AssignmentStatus)) }
  def assignment_status; end

  sig { returns(::T.all(ActiveSupport::StringInquirer, Filter::IndexedBy)) }
  def indexed_by; end

  sig { returns(::T.all(ActiveSupport::StringInquirer, Filter::SortedBy)) }
  def sorted_by; end

  sig { returns(::T.nilable(::T::Range[ActiveSupport::TimeWithZone])) }
  def creation_window; end

  sig { returns(::T.nilable(::T::Range[ActiveSupport::TimeWithZone])) }
  def closure_window; end

  sig { returns(::T::Array[String]) }
  def terms; end

  sig { params(value: ::T.nilable(::T.any(String, ::T::Array[String]))).void }
  def terms=(value); end

  sig { returns(::T::Array[String]) }
  def column_ids; end

  sig { params(value: ::T.nilable(::T.any(String, ::T::Array[String]))).void }
  def column_ids=(value); end
end

class Event
  module Action
    interface!

    sig { abstract.returns(::T::Boolean) }
    def card_assigned?; end

    sig { abstract.returns(::T::Boolean) }
    def card_unassigned?; end

    sig { abstract.returns(::T::Boolean) }
    def card_published?; end

    sig { abstract.returns(::T::Boolean) }
    def card_closed?; end

    sig { abstract.returns(::T::Boolean) }
    def card_reopened?; end

    sig { abstract.returns(::T::Boolean) }
    def card_postponed?; end

    sig { abstract.returns(::T::Boolean) }
    def card_auto_postponed?; end

    sig { abstract.returns(::T::Boolean) }
    def card_resumed?; end

    sig { abstract.returns(::T::Boolean) }
    def card_title_changed?; end

    sig { abstract.returns(::T::Boolean) }
    def card_board_changed?; end

    sig { abstract.returns(::T::Boolean) }
    def card_collection_changed?; end

    sig { abstract.returns(::T::Boolean) }
    def card_triaged?; end

    sig { abstract.returns(::T::Boolean) }
    def card_sent_back_to_triage?; end

    sig { abstract.returns(::T::Boolean) }
    def comment_created?; end
  end
end

module AccountSlug
  PATTERN = T.let(T.unsafe(nil), Regexp)
  PATH_INFO_MATCH = T.let(T.unsafe(nil), Regexp)

  sig { params(id: Integer).returns(String) }
  def self.encode(id); end

  sig { params(slug: String).returns(Integer) }
  def self.decode(slug); end
end

# What ZipFile reads from and writes to. Sorbet types are nominal, so these are
# the concrete IOs the app passes rather than interfaces.
ZipFile::Reader::Source = T.type_alias { ::T.any(IO, Tempfile, ZipKit::RemoteIO) }
ZipFile::Writer::Output = T.type_alias { ::T.any(IO, Tempfile) }

class Account
  sig { returns(Account::JoinCode) }
  def join_code; end
end

class Webhook
  sig { returns(Webhook::DelinquencyTracker) }
  def delinquency_tracker; end
end

class Webhook::DelinquencyTracker
  sig { returns(Integer) }
  def consecutive_failures_count; end
end

class Webhook::Delivery
  include ActionDispatch::Routing::PolymorphicRoutes

  sig { params(arg0: ::T::Hash[Symbol, ::T.untyped]).returns(::T::Hash[Symbol, ::T.untyped]) }
  def response=(arg0); end
end

class Identity
  sig { params(email_address: ::T.nilable(String)).returns(::T.nilable(Identity)) }
  def self.find_by_email_address(email_address); end
end

module Card::GeneratedRelationMethods
  sig { params(id: ::T.untyped).returns(::T.nilable(Card)) }
  def find_by_id(id); end
end

module Filter::GeneratedRelationMethods
  sig { params(params: ::T.untyped).returns(Filter) }
  def from_params(params); end

  sig { params(attrs: ::T.untyped).returns(Filter) }
  def remember(attrs); end
end

module Notification::GeneratedRelationMethods
  sig { returns(::T::Array[Notification]) }
  def read_all; end
end

