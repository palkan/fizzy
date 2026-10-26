# typed: true

# Used by controllers, and as a view helper
module LoginHelper
  #: () -> String
  def login_url
    main_app.new_session_path(script_name: nil)
  end

  #: () -> String
  def logout_url
    main_app.new_session_path
  end

  #: () -> void
  def redirect_to_login_url
    #: self as ActionController::Base & LoginHelper
    redirect_to login_url, allow_other_host: true
  end

  #: () -> void
  def redirect_to_logout_url
    #: self as ActionController::Base & LoginHelper
    redirect_to logout_url, allow_other_host: true
  end
end
