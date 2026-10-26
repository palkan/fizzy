# typed: true

# @requires_ancestor: User
module User::Watcher
  extend ActiveSupport::Concern
  included do
    #: self as singleton(User)
    has_many :watches, dependent: :destroy
  end
end
