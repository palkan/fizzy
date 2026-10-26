# typed: true

# @requires_ancestor: Card
module Card::Pinnable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Card)
    has_many :pins, dependent: :destroy

    after_update_commit :broadcast_pin_updates, if: :preview_changed?
  end

  #: (User) -> bool
  def pinned_by?(user)
    pins.exists?(user: user)
  end

  #: (User) -> Pin?
  def pin_for(user)
    pins.find_by(user: user)
  end

  #: (User) -> Pin
  def pin_by(user)
    pins.find_or_create_by!(user: user)
  end

  #: (User) -> Pin?
  def unpin_by(user)
    pins.find_by(user: user).tap { it&.destroy }
  end

  private
    def broadcast_pin_updates
      pins.find_each do |pin|
        pin.broadcast_replace_later_to [ pin.user, :pins_tray ], partial: "my/pins/pin"
      end
    end
end
