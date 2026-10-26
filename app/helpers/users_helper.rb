# typed: true

# @requires_ancestor: ActionView::Base
module UsersHelper
  #: (User) -> String
  def role_display_name(user)
    case user.role
    when "admin" then "Administrator"
    else user.role.titleize
    end
  end
end
