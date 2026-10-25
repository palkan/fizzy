module User::Timelined
  # @type instance: User
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(User)
    has_many :accessible_events, through: :boards, source: :events
  end

  #: (ActiveSupport::TimeWithZone, filter: Filter) -> User::DayTimeline
  def timeline_for(day, filter:)
    User::DayTimeline.new(self, day, filter)
  end
end
