# typed: true

# @requires_ancestor: Identity
module Identity::Joinable
  extend ActiveSupport::Concern

  #: (Account account, **untyped attributes) -> bool
  def join(account, **attributes)
    attributes[:name] ||= email_address

    transaction do
      account.users.find_or_create_by!(identity: self) do |user|
        user.assign_attributes(attributes)
      end.previously_new_record?
    end
  end
end
