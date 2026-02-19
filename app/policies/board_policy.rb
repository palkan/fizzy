class BoardPolicy < ApplicationPolicy
  relation_scope do |scope|
    scope.left_joins(:accesses).where(all_access: true).or(
      scope.left_joins(:accesses).where(accesses: { user_id: user.id })
    ).distinct
  end

  def create?
    true
  end

  def show?
    record.all_access? || check?(:has_access?)
  end

  def manage?
    check?(:board_admin?)
  end

  def has_access?
    record.accesses.exists?(user: user)
  end

  def board_admin?
    admin? || record.creator == user
  end
end
