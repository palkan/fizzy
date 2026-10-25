module Comment::Promptable
  # @type instance: Comment
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Comment)
    # @rbs skip -- declared in sig/generated/inline.rbs
    include Rails.application.routes.url_helpers
  end

  #: () -> String
  def to_prompt
    <<~PROMPT
        BEGIN OF COMMENT #{id}

        **Content:**

        #{body.to_plain_text.first(5000)}

        #### Metadata

        * Id: #{id}
        * Card id: #{card.number}
        * Card title: #{card.title}
        * Created by: #{creator.name}}
        * Created at: #{created_at}}
        * Path: #{card_path(card, anchor: ActionView::RecordIdentifier.dom_id(self), script_name: account.slug)}
        END OF COMMENT #{id}
      PROMPT
  end
end
