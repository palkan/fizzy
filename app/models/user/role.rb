module User::Role
  extend ActiveSupport::Concern

  ROLE_LEVELS = { viewer: 0, member: 1, admin: 2, owner: 2 }.freeze

  included do
    enum :role, %i[ owner admin member viewer system ].index_by(&:itself), scopes: false

    scope :owner, -> { where(active: true, role: :owner) }
    scope :admin, -> { where(active: true, role: %i[ owner admin ]) }
    scope :member, -> { where(active: true, role: :member) }
    scope :active, -> { where(active: true, role: %i[ owner admin member viewer ]) }
    scope :contributor, -> { where(active: true, role: %i[ owner admin member ]) }

    after_update_commit :cleanup_on_viewer_demotion, if: :viewer?

    def admin?
      super || owner?
    end
  end

  def contributor?
    owner? || admin? || member?
  end

  def role_level
    ROLE_LEVELS.fetch(role.to_sym)
  end

  def role_at_least?(min_role)
    role_level >= ROLE_LEVELS.fetch(min_role.to_sym)
  end

  def can_change?(other)
    (admin? && !other.owner?) || other == self
  end

  def can_administer?(other)
    admin? && !other.owner? && other != self
  end

  def can_administer_board?(board)
    contributor? && (admin? || board.creator == self)
  end

  def can_administer_card?(card)
    contributor? && (admin? || card.creator == self)
  end

  private
    def cleanup_on_viewer_demotion
      return unless role_previously_changed? && viewer?
      assignments.destroy_all
      Card.where(creator: self).drafted.destroy_all
    end
end
