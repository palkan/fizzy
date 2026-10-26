# typed: true

class User::Filtering
  #: User
  attr_reader :user
  #: Filter
  attr_reader :filter
  #: bool?
  attr_reader :expanded

  delegate :as_params, :single_board, to: :filter
  delegate :only_closed?, to: :filter

  #: (User, Filter, ?expanded: bool?) -> void
  def initialize(user, filter, expanded: false)
    @user, @filter, @expanded = user, filter, expanded
  end

  def boards
    @boards ||= user.boards.ordered_by_recently_accessed
  end

  def selected_board_titles
    filter.board_titles
  end

  def selected_boards_label
    filter.boards_label
  end

  def tags
    @tags ||= account.tags.all.alphabetically
  end

  def users
    @users ||= account.users.active.alphabetically
  end

  def filters
    @filters ||= user.filters.all
  end

  #: () -> bool?
  def expanded?
    @expanded
  end

  #: () -> bool
  def any?
    filter.used?(ignore_boards: true)
  end

  #: () -> bool
  def show_indexed_by?
    !filter.indexed_by.all?
  end

  #: () -> bool
  def show_sorted_by?
    !filter.sorted_by.latest?
  end

  #: () -> bool?
  def show_tags?
    return unless Tag.any?
    filter.tags.any?
  end

  #: () -> bool
  def show_assignees?
    filter.assignees.any?
  end

  #: () -> bool
  def show_creators?
    filter.creators.any?
  end

  #: () -> bool
  def show_closers?
    filter.closers.any?
  end

  #: () -> bool
  def show_boards?
    filter.boards.any?
  end

  #: () -> Board?
  def single_board_or_first
    # Default to the first selected or, when no selection, to the first one
    filter.boards.first || boards.first
  end

  #: () -> String
  def cache_key
    ActiveSupport::Cache.expand_cache_key([ user, filter, expanded?, boards, tags, users, filters ], "user-filtering")
  end

  private
    def account
      user.account
    end
end
