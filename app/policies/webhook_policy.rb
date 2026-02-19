class WebhookPolicy < ApplicationPolicy
  # Board is required for some rules
  authorize :board, optional: true

  def index?
    allowed_to?(:manage?, board)
  end

  def create?
    allowed_to?(:manage?, board)
  end

  def show?
    allowed_to?(:manage?, record.board)
  end

  def manage?
    allowed_to?(:manage?, record.board)
  end
end
