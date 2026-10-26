# typed: true

# @requires_ancestor: ActionController::Base
# @requires_ancestor: GeneratedUrlHelpersModule
module Authentication
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ActionController::Base)
    before_action :require_account # Checking and setting account must happen first
    before_action :require_authentication
    helper_method :authenticated?
    helper_method :email_address_pending_authentication

    etag do
      #: self as ActionController::Base & Authentication
      Current.identity!.id if authenticated?
    end

    include Authentication::ViaMagicLink, LoginHelper
  end

  # Not `@requires_ancestor: singleton(ActionController::Base)`: ActiveStorage::Authorize, a module, includes this concern
  module ClassMethods
    #: (**untyped) -> void
    def require_unauthenticated_access(**options)
      #: self as singleton(ActionController::Base) & Authentication::ClassMethods
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end

    #: (**untyped) -> void
    def allow_unauthenticated_access(**options)
      #: self as singleton(ActionController::Base) & Authorization::ClassMethods
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
      allow_unauthorized_access **options
    end

    #: (**untyped) -> void
    def disallow_account_scope(**options)
      #: self as singleton(ActionController::Base)
      skip_before_action :require_account, **options
      before_action :redirect_tenanted_request, **options
    end
  end

  private
    #: () -> bool
    def authenticated?
      Current.identity.present?
    end

    def require_account
      unless Current.account.present?
        redirect_to main_app.session_menu_path(script_name: nil)
      end
    end

    def require_authentication
      resume_session || authenticate_by_bearer_token || request_authentication
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session
      end
    end

    #: () -> Session?
    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    def authenticate_by_bearer_token
      if request.authorization.to_s.include?("Bearer")
        if bearer_token_authenticatable_request?
          authenticate_or_request_with_http_token do |token|
            if identity = Identity.find_by_permissable_access_token(token, method: request.method)
              Current.identity = identity
            end
          end
        else
          request_http_token_authentication
        end
      end
    end

    #: () -> bool
    def bearer_token_authenticatable_request?
      request.format.json?
    end

    def request_authentication
      if Current.account.present?
        session[:return_to_after_authenticating] = request.url
      end

      redirect_to_login_url
    end

    #: () -> String
    def after_authentication_url
      session.delete(:return_to_after_authenticating) || landing_url
    end

    def redirect_authenticated_user
      redirect_to main_app.root_url if authenticated?
    end

    def redirect_tenanted_request
      redirect_to main_app.root_url if Current.account.present?
    end

    #: (Identity) -> Session
    def start_new_session_for(identity)
      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    #: (Session session) -> untyped
    def set_current_session(session)
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end

    #: () -> void
    def terminate_session
      Current.session!.destroy
      cookies.delete(:session_token)
    end

    #: () -> String?
    def session_token
      cookies[:session_token]
    end
end
