module Card::Broadcastable
  # @type instance: Card
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Card)
    broadcasts_refreshes

    before_update :remember_if_preview_changed
  end

  private
    def remember_if_preview_changed
      @preview_changed ||= title_changed? || column_id_changed? || board_id_changed?
    end

    def preview_changed?
      @preview_changed
    end
end
