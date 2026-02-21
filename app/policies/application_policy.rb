class ApplicationPolicy < ActionPolicy::Base
  authorize :user
  authorize :account

  delegate :admin?, :owner?, :viewer?, to: :user

  def show?
    false
  end

  def manage?
    false
  end

  def not_viewer?
    !viewer?
  end
end
