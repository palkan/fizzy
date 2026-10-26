# typed: true

# @requires_ancestor: User
module User::Named
  extend ActiveSupport::Concern

  included do
    #: self as singleton(User)
    scope :alphabetically, -> { order("lower(name)") }
  end

  #: () -> String
  def first_name
    # Names are validated to be present
    name.split(/\s/).first #: as !nil
  end

  #: () -> String?
  def last_name
    name.split(/\s/, 2).last
  end

  #: () -> String
  def initials
    name.scan(/\b\p{L}/).join.upcase
  end

  #: () -> String
  def familiar_name
    names = name.split
    return name if names.length <= 1
    "#{names.first}\u00A0#{names.drop(1).map { |n| "#{n[0]}." }.join}"
  end
end
