# typed: true

class TimeWindowParser
  #: ActiveSupport::TimeWithZone
  attr_reader :now

  HUMAN_NAMES_BY_VALUE = {
    "today" => "Today",
    "yesterday" => "Yesterday",
    "thisweek" => "This week",
    "thismonth" => "This month",
    "thisyear" => "This year",
    "lastweek" => "Last week",
    "lastmonth" => "Last month",
    "lastyear" => "Last year"
  }

  VALUES = HUMAN_NAMES_BY_VALUE.keys

  #: (String? string) -> Range[ActiveSupport::TimeWithZone]?
  def self.parse(string)
    new.parse(string)
  end

  #: (String value) -> String?
  def self.human_name_for(value)
    HUMAN_NAMES_BY_VALUE[value]
  end

  #: (?now: ActiveSupport::TimeWithZone) -> void
  def initialize(now: Time.current)
    @now = now
  end

  #: (String? string) -> Range[ActiveSupport::TimeWithZone]?
  def parse(string)
    case normalize(string)
    when "today"
      now.all_day
    when "yesterday"
      (now - 1.day).all_day
    when "thisweek"
      now.all_week
    when "thismonth"
      now.all_month
    when "thisyear"
      now.all_year
    when "lastweek"
      (now - 1.week).all_week
    when "lastmonth"
      (now - 1.month).all_month
    when "lastyear"
      (now - 1.year).all_year
    end
  end

  private
    #: (String? string) -> String?
    def normalize(string)
      if string
        string.downcase.gsub(/[\s_\-]/, "")
      end
    end
end
