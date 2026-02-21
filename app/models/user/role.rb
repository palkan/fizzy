module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ owner admin member viewer system ].index_by(&:itself), scopes: false

    scope :owner, -> { where(active: true, role: :owner) }
    scope :admin, -> { where(active: true, role: %i[ owner admin ]) }
    scope :member, -> { where(active: true, role: :member) }
    scope :viewer, -> { where(active: true, role: :viewer) }
    scope :active, -> { where(active: true).where.not(role: :system) }

    def admin?
      super || owner?
    end
  end
end
