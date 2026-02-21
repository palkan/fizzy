module User::Accessor
  extend ActiveSupport::Concern

  included do
    has_many :accesses, dependent: :destroy
    has_many :boards, through: :accesses
    has_many :accessible_columns, through: :boards, source: :columns
    has_many :accessible_cards, through: :boards, source: :cards
    has_many :accessible_comments, through: :accessible_cards, source: :comments

    after_create_commit :grant_access_to_boards, unless: :system?
  end

  def accessible_columns
    if contributor?
      super
    else
      super.where(hidden_from_viewers: false)
    end
  end

  def accessible_cards
    if contributor?
      super
    else
      hidden_column_ids = Column.where(board_id: board_ids, hidden_from_viewers: true).select(:id)
      super.where(column_id: [nil]).or(super.where.not(column_id: hidden_column_ids))
    end
  end

  def draft_new_card_in(board)
    board.cards.find_or_initialize_by(creator: self, status: "drafted").tap do |card|
      card.update!(created_at: Time.current, updated_at: Time.current, last_active_at: Time.current)
    end
  end

  private
    def grant_access_to_boards
      Access.insert_all account.boards.all_access.ids.collect { |board_id| { id: ActiveRecord::Type::Uuid.generate, board_id: board_id, user_id: id, account_id: account.id } }
    end
end
