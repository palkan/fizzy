class Column < ApplicationRecord
  include Colored, Positioned

  MIN_ROLES = %w[ viewer member admin ].freeze

  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  has_many :cards, dependent: :nullify

  validates :min_role, inclusion: { in: MIN_ROLES }

  scope :visible_to, ->(user) {
    if user&.admin?
      all
    elsif user&.member?
      where(min_role: %w[viewer member])
    elsif user&.viewer?
      where(min_role: "viewer")
    else
      where(min_role: "viewer")
    end
  }

  scope :publicly_visible, -> { where(min_role: "viewer") }

  after_save_commit    -> { cards.touch_all }, if: -> { saved_change_to_name? || saved_change_to_color? }
  after_destroy_commit -> { board.cards.touch_all }

  def restricted?
    min_role != "viewer"
  end
end
