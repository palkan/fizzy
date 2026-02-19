class AccountPolicy < ApplicationPolicy
  def show?
    true
  end

  def manage?
    check?(:admin?)
  end

  # Billing management requires account admin — same as manage? today,
  # but named separately so billing rules can diverge independently
  def manage_billing?
    check?(:admin?)
  end

  def destroy?
    check?(:owner?)
  end
end
