class ColumnPolicy < ApplicationPolicy
  authorize :board, optional: true

  def create?
    allowed_to?(:manage?, board)
  end

  def show?
    allowed_to?(:show?, record.board)
  end

  def manage?
    allowed_to?(:manage?, record.board)
  end
end
