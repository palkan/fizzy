# typed: true

require "zlib"

# @requires_ancestor: User
module User::Avatar
  extend ActiveSupport::Concern

  ALLOWED_AVATAR_CONTENT_TYPES = %w[ image/jpeg image/png image/gif image/webp ].freeze
  MAX_AVATAR_DIMENSIONS = { width: 4096, height: 4096 }.freeze
  AVATAR_COLORS = %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ].freeze

  included do
    #: self as singleton(User)
    has_one_attached :avatar, dependent: :purge_later do |attachable|
      attachable.variant :thumb, resize_to_fill: [ 256, 256 ], process: :immediately
    end

    scope :with_avatars, -> { preload(:account, :avatar_attachment) }

    validate :avatar_content_type_allowed, :avatar_dimensions_allowed, if: :avatar_attached?
  end

  #: () -> bool
  def avatar_attached?
    avatar.attached?
  end

  def avatar_thumbnail
    avatar.variable? ? avatar.variant(:thumb) : avatar
  end

  #: () -> String
  def avatar_background_color
    AVATAR_COLORS.fetch(Zlib.crc32(to_param.to_s) % AVATAR_COLORS.size)
  end

  # Avatars are always publicly accessible
  #: () -> bool
  def publicly_accessible?
    true
  end

  private
    def avatar_content_type_allowed
      unless ALLOWED_AVATAR_CONTENT_TYPES.include?(avatar.content_type)
        errors.add(:avatar, "must be a JPEG, PNG, GIF, or WebP image")
      end
    end

    def avatar_dimensions_allowed
      # Only validated when an avatar is attached
      blob = avatar.blob #: as !nil
      return unless blob.analyzed? || blob.analyze

      width = blob.metadata[:width]
      height = blob.metadata[:height]

      if width && width > MAX_AVATAR_DIMENSIONS[:width]
        errors.add(:avatar, "width must be less than #{MAX_AVATAR_DIMENSIONS[:width]}px")
      end

      if height && height > MAX_AVATAR_DIMENSIONS[:height]
        errors.add(:avatar, "height must be less than #{MAX_AVATAR_DIMENSIONS[:height]}px")
      end
    end
end
