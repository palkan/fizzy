module Column::Accessible
  extend ActiveSupport::Concern

  ROLE_RANKS = { "viewer" => 0, "member" => 1, "admin" => 2 }.freeze

  included do
    enum :min_role, { viewer: 0, member: 1, admin: 2 }, default: :viewer

    scope :accessible_by, ->(user) {
      if user.admin?
        all
      else
        where("columns.min_role <= ?", ROLE_RANKS.fetch(user.role, 0))
      end
    }
  end

  def accessible_to?(user)
    user.admin? || ROLE_RANKS.fetch(min_role, 0) <= ROLE_RANKS.fetch(user.role, 0)
  end
end
