class ApplicationPolicy < ActionPolicy::Base
  authorize :user
  authorize :account

  delegate :admin?, :owner?, to: :user

  def show?
    false
  end

  def manage?
    false
  end
end
