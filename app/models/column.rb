class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  has_many :cards, dependent: :nullify

  scope :visible_to, ->(user) {
    if user&.contributor?
      all
    else
      where(hidden_from_viewers: false)
    end
  }

  scope :viewer_visible, -> { where(hidden_from_viewers: false) }

  after_save_commit    -> { cards.touch_all }, if: -> { saved_change_to_name? || saved_change_to_color? }
  after_destroy_commit -> { board.cards.touch_all }
end
