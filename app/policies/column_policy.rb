class ColumnPolicy < ApplicationPolicy
  authorize :board, optional: true

  def create?
    allowed_to?(:manage?, board)
  end

  def show?
    if allowed_to?(:manage?, record.board) || record.accessible_to?(user)
      allowed_to?(:show?, record.board)
    else
      false
    end
  end

  def manage?
    allowed_to?(:manage?, record.board)
  end
end
