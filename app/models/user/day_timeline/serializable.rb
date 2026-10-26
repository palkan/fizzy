# typed: true

# @requires_ancestor: User::DayTimeline
module User::DayTimeline::Serializable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(User::DayTimeline)
    include GlobalID::Identification # For active job serialization
  end

  # @requires_ancestor: singleton(User::DayTimeline)
  module ClassMethods
    #: (String) -> User::DayTimeline
    def find(id)
      data = JSON.parse(id).with_indifferent_access
      user = User.find(data[:user_id])
      day = Time.zone.parse(data[:day]) #: as ActiveSupport::TimeWithZone
      filter = user.filters.from_params data[:filter_params]

      User::DayTimeline.new(user, day, filter)
    end

    #: () -> bool
    def tenanted?
      # TODO: Check with Mike
      false
    end
  end

  #: () -> String
  def id
    to_json
  end

  #: (?Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def as_json(options = {})
    { user_id: user.id, day: day.to_s, filter_params: filter.as_params }
  end
end
