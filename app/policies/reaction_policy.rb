class ReactionPolicy < ApplicationPolicy
  def create?
    true
  end

  def manage?
    check?(:creator?)
  end

  def creator?
    record.reacter == user
  end
end
