module CommentsHelper
  # @type instance: ActionView::Base
  #: (Card) -> String
  def new_comment_placeholder(card)
    if card.creator == Current.user && card.comments.empty?
      "Next, add some notes, context, pictures, or video about this…"
    else
      "Type your comment…"
    end
  end
end
