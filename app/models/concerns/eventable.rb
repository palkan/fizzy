module Eventable
  # @type instance: Eventable & Eventable::_Includer & ApplicationRecord
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationRecord)
    has_many :events, as: :eventable, dependent: :destroy
  end

  #: (String | Symbol action, ?creator: User, ?board: Board, **untyped particulars) -> Event?
  def track_event(action, creator: Current.user, board: self.board, **particulars)
    if should_track_event?
      board.events.create!(action: "#{eventable_prefix}_#{action}", creator:, board:, eventable: self, particulars:)
    end
  end

  #: (Event) -> void
  def event_was_created(event)
  end

  private
    #: () -> bool
    def should_track_event?
      true
    end

    #: () -> String
    def eventable_prefix
      self.class.name.demodulize.underscore
    end
end
