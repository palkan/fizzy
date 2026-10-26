# typed: true

# @requires_ancestor: ActionView::Base
module CommentsHelper
  #: (Card) -> String
  def new_comment_placeholder(card)
    if card.creator == Current.user && card.comments.empty?
      "Next, add some notes, context, pictures, or video about this…"
    else
      "Type your comment…"
    end
  end
end
