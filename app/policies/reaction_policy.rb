class ReactionPolicy < ApplicationPolicy
  def create?
    check?(:not_viewer?)
  end

  def manage?
    check?(:creator?)
  end

  def creator?
    record.reacter == user
  end
end
