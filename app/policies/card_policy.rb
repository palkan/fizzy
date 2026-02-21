class CardPolicy < ApplicationPolicy
  authorize :board, optional: true

  relation_scope do |scope|
    base = scope.left_joins(board: :accesses).where(boards: { all_access: true }).or(
      scope.left_joins(board: :accesses).where(accesses: { user_id: user.id })
    ).distinct

    base.column_accessible_by(user)
  end

  def create?
    check?(:not_viewer?) && allowed_to?(:show?, board)
  end

  def show?
    if record.column && !record.column.accessible_to?(user)
      false
    else
      allowed_to?(:show?, record.board)
    end
  end

  def manage?
    check?(:not_viewer?) && allowed_to?(:show?, record.board)
  end

  def destroy?
    allowed_to?(:manage?) &&
      check?(:can_administer?)
  end

  def can_administer?
    admin? || record.creator == user
  end
end
