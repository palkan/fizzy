module RichTextHelper
  # @type instance: ActionView::Base
  #: (Board) -> ActiveSupport::SafeBuffer
  def mentions_prompt(board)
    content_tag "lexxy-prompt", "", trigger: "@", src: prompts_board_users_path(board), name: "mention"
  end

  #: () -> ActiveSupport::SafeBuffer
  def global_mentions_prompt
    content_tag "lexxy-prompt", "", trigger: "@", src: prompts_users_path, name: "mention"
  end

  #: () -> ActiveSupport::SafeBuffer
  def cards_prompt
    content_tag "lexxy-prompt", "", trigger: "#", src: prompts_cards_path, name: "card", "insert-editable-text": true, "remote-filtering": true, "supports-space-in-searches": true
  end

  #: (Board) -> ActiveSupport::SafeBuffer
  def general_prompts(board)
    safe_join([ mentions_prompt(board), cards_prompt ])
  end
end
