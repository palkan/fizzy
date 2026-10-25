module User::Watcher
  # @type instance: User
  extend ActiveSupport::Concern
  included do
    # @type self: singleton(User)
    has_many :watches, dependent: :destroy
  end
end
