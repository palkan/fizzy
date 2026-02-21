class UserPolicy < ApplicationPolicy
  relation_scope do |scope|
    scope.where(account:)
  end

  relation_scope :assignable do |scope|
    scope.where.not(role: %i[ system viewer ])
  end

  def show?
    check?(:same_account?)
  end

  def manage?
    (admin? && !record.owner?) || record == user
  end

  # Custom rule (not CRUD) because role changes are authorized differently
  # from user management — admins can manage users (including themselves)
  # but cannot change their own role
  def change_role?
    check?(:can_administer?)
  end

  def same_account?
    record.account_id == account.id
  end

  def can_administer?
    admin? && !record.owner? && record != user
  end
end
