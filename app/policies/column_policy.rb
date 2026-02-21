class ColumnPolicy < ApplicationPolicy
  authorize :board, optional: true

  def create?
    allowed_to?(:manage?, board)
  end

  def show?
    if viewer? && record.viewer_restricted?
      false
    else
      allowed_to?(:show?, record.board)
    end
  end

  def manage?
    allowed_to?(:manage?, record.board)
  end
end
