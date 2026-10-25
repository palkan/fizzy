module User::Attachable
  # @type instance: User
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(User)
    include ActionText::Attachable

    def attachable_plain_text_representation(...)
      "@#{first_name.downcase}"
    end
  end
end
