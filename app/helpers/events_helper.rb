# typed: true

# @requires_ancestor: ActionView::Base
module EventsHelper
  #: (Event) -> String
  def event_action_icon(event)
    case event.action
    when "card_assigned"
      "assigned"
    when "card_unassigned"
      "minus"
    when "comment_created"
      "comment"
    when "card_title_changed"
      "rename"
    when "card_board_changed", "card_triaged", "card_postponed", "card_auto_postponed"
      "move"
    else
      "person"
    end
  end

  #: (untyped column, Integer hour) { (?) -> untyped } -> ActiveSupport::SafeBuffer
  def events_at_hour_container(column, hour, &block)
    tag.div class: "events__time-block", style: "grid-area: #{25 - hour}/#{column.index}", &block
  end
end
