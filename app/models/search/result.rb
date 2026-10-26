# typed: true

class Search::Result < ApplicationRecord
  attribute :card_id, :uuid
  attribute :comment_id, :uuid
  attribute :creator_id, :uuid

  belongs_to :creator, class_name: "User"
  belongs_to :card, foreign_key: :card_id, optional: true
  belongs_to :comment, foreign_key: :comment_id, optional: true

  #: () -> String?
  def card_title
    if card_id
      card = self.card #: as !nil
      highlight(card.title, show: :full)
    end
  end

  #: () -> String?
  def card_description
    if card_id
      card = self.card #: as !nil
      highlight(card.description.to_plain_text, show: :snippet)
    end
  end

  #: () -> String?
  def comment_body
    if comment_id
      comment = self.comment #: as !nil
      highlight(comment.body.to_plain_text, show: :snippet)
    end
  end

  #: () -> (Card | Comment | nil)
  def source
    comment_id.present? ? comment : card
  end

  def readonly?
    true
  end

  private
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
