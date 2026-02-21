module Card::ColumnAccessible
  extend ActiveSupport::Concern

  included do
    scope :column_accessible_by, ->(user) {
      if user.admin?
        all
      else
        rank = Column::Accessible::ROLE_RANKS.fetch(user.role, 0)
        left_joins(:column).where("columns.min_role IS NULL OR columns.min_role <= ?", rank)
      end
    }
  end
end
