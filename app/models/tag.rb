# typed: true

class Tag < ApplicationRecord
  include Filterable

  belongs_to :account, default: -> { Current.account }
  has_many :taggings, dependent: :destroy
  has_many :cards, through: :taggings

  validates :title, format: { without: /\A#/ }
  normalizes :title, with: -> { it.downcase }

  scope :alphabetically, -> { order("lower(title)") }
  scope :unused, -> { left_outer_joins(:taggings).where(taggings: { id: nil }) }

  #: () -> String
  def hashtag
    # Tags are always created from a title.
    title = self.title #: as !nil
    "#" + title
  end

  #: () -> Integer
  def cards_count
    cards.open.count
  end
end
