class CardPolicy < ApplicationPolicy
  authorize :board, optional: true

  relation_scope do |scope|
    base = scope.left_joins(board: :accesses).where(boards: { all_access: true }).or(
      scope.left_joins(board: :accesses).where(accesses: { user_id: user.id })
    ).distinct

    if viewer?
      base.left_joins(:column).where(columns: { viewer_restricted: [false, nil] }).or(
        base.left_joins(:column).where(column_id: nil)
      )
    else
      base
    end
  end

  def create?
    check?(:not_viewer?) && allowed_to?(:show?, board)
  end

  def show?
    if viewer? && record.column&.viewer_restricted?
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
