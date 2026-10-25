module Notification::Pushable
  # @type instance: Notification
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(Notification)
    class_attribute :push_targets, default: [] #: Array[singleton(Notification::PushTarget)]

    after_save_commit :push_later, if: :source_id_previously_changed?
  end

  module ClassMethods
    # @type instance: singleton(Notification)
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
    Notification::PushJob.perform_later(self)
  end

  #: () -> void
  def push
    return unless pushable?

    self.class.push_targets.each { |target| push_to(target) }
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
