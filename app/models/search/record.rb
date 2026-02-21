class Search::Record < ApplicationRecord
  include const_get(connection.adapter_name)

  belongs_to :searchable, polymorphic: true
  belongs_to :card

  validates :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :created_at, presence: true

  class << self
    def upsert!(attributes)
      record = find_by(searchable_type: attributes[:searchable_type], searchable_id: attributes[:searchable_id])
      if record
        record.update!(attributes)
        record
      else
        create!(attributes)
      end
    end

    def card_join
      "INNER JOIN #{table_name} ON #{table_name}.card_id = cards.id"
    end
  end

  scope :for_query, ->(query, user:) do
    query = Search::Query.wrap(query)

    if query.valid? && user.board_ids.any?
      result = matching(query.to_s, user.account_id).where(account_id: user.account_id, board_id: user.board_ids)
      if user.admin?
        result
      else
        rank = Column::Accessible::ROLE_RANKS.fetch(user.role, 0)
        restricted_card_ids = Card.joins(:column).where("columns.min_role > ?", rank).select(:id)
        result.where.not(card_id: restricted_card_ids)
      end
    else
      none
    end
  end

  scope :search, ->(query, user:) do
    query = Search::Query.wrap(query)

    for_query(query, user: user)
      .includes(:searchable, card: [ :board, :creator ])
      .order(created_at: :desc)
      .select(:id, :account_id, :searchable_type, :searchable_id, :card_id, :board_id, :title, :content, :created_at, *search_fields(query))
  end

  def source
    searchable_type == "Comment" ? searchable : card
  end

  def comment
    searchable if searchable_type == "Comment"
  end
end
