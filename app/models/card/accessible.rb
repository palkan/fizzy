# typed: true

# @requires_ancestor: Card
module Card::Accessible
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Card)
    delegate :accessible_to?, to: :board
  end

  #: () -> bool
  def publicly_accessible?
    published? && board.publicly_accessible?
  end

  #: () -> void
  def clean_inaccessible_data
    accessible_user_ids = board.accesses.pluck(:user_id)
    pins.where.not(user_id: accessible_user_ids).in_batches.destroy_all
    watches.where.not(user_id: accessible_user_ids).in_batches.destroy_all
  end

  private
    def grant_access_to_assignees
      board.accesses.grant_to(assignees)
    end

    def clean_inaccessible_data_later
      card = self #: as Card
      Card::CleanInaccessibleDataJob.perform_later(card)
    end
end
