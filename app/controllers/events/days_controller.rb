class Events::DaysController < ApplicationController
  include DayTimelinesScoped

  skip_authorization

  def index
    fresh_when @day_timeline
  end
end
