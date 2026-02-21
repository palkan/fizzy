module UsersHelper
  def role_display_name(user)
    case user.role
    when "admin" then "Administrator"
    when "viewer" then "Viewer"
    else user.role.titleize
    end
  end
end
