module User::Assignee
  # @type instance: User
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(User)
    has_many :assignments, foreign_key: :assignee_id, dependent: :destroy
    has_many :assignings, foreign_key: :assigner_id, class_name: "Assignment"
    has_many :assigned_cards, through: :assignments, source: :card
  end
end
