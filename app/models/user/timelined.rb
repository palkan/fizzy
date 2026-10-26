# typed: true

# @requires_ancestor: User
module User::Timelined
  extend ActiveSupport::Concern

  included do
    #: self as singleton(User)
    has_many :accessible_events, through: :boards, source: :events
  end

  #: (ActiveSupport::TimeWithZone, filter: Filter) -> User::DayTimeline
  def timeline_for(day, filter:)
    user = self #: as User
    User::DayTimeline.new(user, day, filter)
  end
end
