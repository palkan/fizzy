class CommentPolicy < ApplicationPolicy
  # Card is only required for some rules
  authorize :card, optional: true

  def create?
    allowed_to?(:show?, card)
  end

  def show?
    allowed_to?(:show?, record.card)
  end

  def manage?
    allowed_to?(:show?) && check?(:creator?)
  end

  def creator?
    record.creator == user
  end
end
