# typed: true

# @requires_ancestor: Card
module Card::Statuses
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Card)
    enum :status, %w[ drafted published ].index_by(&:itself)

    before_save :mark_if_just_published
    after_create -> {
      #: self as Card
      track_event :published
    }, if: :published?
  end

  #: bool?
  attr_accessor :was_just_published
  alias_method :was_just_published?, :was_just_published

  #: () -> void
  def publish
    transaction do
      self.created_at = Time.current
      published!
      track_event :published
    end
  end

  private
    def mark_if_just_published
      self.was_just_published = true if published? && status_changed?
    end
end
