# typed: true

# @requires_ancestor: Notification
module Notification::Pushable
  extend ActiveSupport::Concern

  included do
    #: self as singleton(Notification)
    class_attribute :push_targets, default: [] #: Array[singleton(Notification::PushTarget)]

    after_save_commit :push_later, if: :source_id_previously_changed?
  end

  # @requires_ancestor: singleton(Notification)
  module ClassMethods
    #: (Symbol | singleton(Notification::PushTarget)) -> void
    def register_push_target(target)
      target = resolve_push_target(target)
      push_targets << target unless push_targets.include?(target)
    end

    private
      def resolve_push_target(target)
        if target.is_a?(Symbol)
          "Notification::PushTarget::#{target.to_s.classify}".constantize
        else
          target
        end
      end
  end

  #: () -> void
  def push_later
    notification = self #: as Notification
    Notification::PushJob.perform_later(notification)
  end

  #: () -> void
  def push
    return unless pushable?

    notification = self #: as Notification
    notification.class.push_targets.each { |target| push_to(target) }
  end

  #: () -> Notification::DefaultPayload
  def payload
    "Notification::#{payload_type}Payload".constantize.new(self)
  end

  private
    def pushable?
      !creator.system? && user.active? && account.active?
    end

    def push_to(target)
      target.process(self)
    end

    def payload_type
      source_type.presence_in(%w[ Event Mention ]) || "Default"
    end
end
