module Comment::Searchable
  # @type instance: Comment
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Comment)
    include ::Searchable
  end

  def search_title
    nil
  end

  def search_content
    body.to_plain_text
  end

  def search_card_id
    card_id
  end

  def search_board_id
    card.board_id
  end

  def searchable?
    card.published?
  end
end
