module User::DayTimeline::Serializable
  # @type instance: User::DayTimeline
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(User::DayTimeline)
    include GlobalID::Identification # For active job serialization
    alias id to_json
  end

  module ClassMethods
    # @type instance: singleton(User::DayTimeline)
    #: (String) -> User::DayTimeline
    def find(id)
      data = JSON.parse(id).with_indifferent_access
      user = User.find(data[:user_id])
      day = Time.zone.parse(data[:day]) #: ActiveSupport::TimeWithZone
      filter = user.filters.from_params data[:filter_params]

      new(user, day, filter)
    end

    #: () -> bool
    def tenanted?
      # TODO: Check with Mike
      false
    end
  end

  #: (?Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def as_json(options = {})
    { user_id: user.id, day: day.to_s, filter_params: filter.as_params }
  end
end
