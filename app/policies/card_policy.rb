class CardPolicy < ApplicationPolicy
  authorize :board, optional: true

  relation_scope do |scope|
    scope.joins(board: :accesses).where(accesses: { user_id: user.id })
  end

  def create?
    allowed_to?(:show?, board)
  end

  def show?
    allowed_to?(:show?, record.board)
  end

  def manage?
    allowed_to?(:show?, record.board)
  end

  def destroy?
    allowed_to?(:manage?) &&
      check?(:can_administer?)
  end

  def can_administer?
    admin? || record.creator == user
  end
end
