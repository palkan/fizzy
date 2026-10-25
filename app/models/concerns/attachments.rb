module Attachments
  # @rbs @remote_images: Array[ActionText::Attachables::RemoteImage]?
  # @rbs @remote_videos: Array[ActionText::Attachables::RemoteVideo]?
  # @rbs @rich_text_record: ActionText::RichText?

  # @type instance: Attachments & ApplicationRecord
  extend ActiveSupport::Concern

  # Variants used by ActionText embeds. Processed immediately on attachment to avoid
  # read replica issues (lazy variants would attempt writes on read replicas).
  #
  # Patched into ActionText::RichText in config/initializers/action_text.rb
  VARIANTS = {
    # vipsthumbnail used to create sized image variants has a intent setting to manage colors during
    # resize. By setting an invalid intent value the gif-incompatible intent filtering is skipped and
    # the gif can be rendered with all its frame intact.
    #
    # Only `n` is accepted as an override, using the full parameter name `intent` doesn’t work.
    #
    # This was cargo-culted from know-it-all and I imagine it may be fixed at some point.
    small: { loader: { n: -1 }, resize_to_limit: [ 800, 600 ] },
    large: { loader: { n: -1 }, resize_to_limit: [ 1024, 768 ] }
  }

  #: () -> (ActiveStorage::Attached::Many | Array[ActiveStorage::Attachment])
  def attachments
    rich_text_record&.embeds || []
  end

  #: () -> bool
  def has_attachments?
    attachments.any?
  end

  #: () -> Array[ActionText::Attachables::RemoteImage]
  def remote_images
    @remote_images ||= rich_text_record&.body&.attachables&.grep(ActionText::Attachables::RemoteImage) || []
  end

  #: () -> bool
  def has_remote_images?
    remote_images.any?
  end

  #: () -> Array[ActionText::Attachables::RemoteVideo]
  def remote_videos
    @remote_videos ||= rich_text_record&.body&.attachables&.grep(ActionText::Attachables::RemoteVideo) || []
  end

  #: () -> bool
  def has_remote_videos?
    remote_videos.any?
  end

  private
    #: () -> ActionText::RichText?
    def rich_text_record
      @rich_text_record ||= begin
        association = self.class.reflect_on_all_associations(:has_one).find { it.klass == ActionText::RichText }
        public_send(association.name)
      end
    end
end
