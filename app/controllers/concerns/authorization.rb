module Authorization
  extend ActiveSupport::Concern

  included do
    include ActionPolicy::Controller

    authorize :user, through: :current_user
    authorize :account, through: :current_account

    rescue_from ActionPolicy::Unauthorized, with: :handle_unauthorized

    before_action :ensure_can_access_account, if: :authenticated_account_access?
  end

  class_methods do
    def skip_authorization
      # No-op marker: documents that this controller intentionally
      # does not perform authorization (authentication is sufficient).
      # When verify_authorized is added to ApplicationController,
      # replace with skip_verify_authorized.
    end

    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
    end

    def require_access_without_a_user(**options)
      skip_before_action :ensure_can_access_account, **options
      before_action :redirect_existing_user, **options
    end
  end

  private
    def current_user
      Current.user
    end

    def current_account
      Current.account
    end

    def handle_unauthorized(exception)
      if exception.rule == :show?
        raise ActiveRecord::RecordNotFound
      else
        head :forbidden
      end
    end

    def ensure_staff
      head :forbidden unless Current.identity.staff?
    end

    def authenticated_account_access?
      Current.account.present? && authenticated?
    end

    def ensure_can_access_account
      unless Current.account.active? && Current.user&.active?
        respond_to do |format|
          format.html { redirect_to session_menu_path(script_name: nil) }
          format.json { head :forbidden }
        end
      end
    end

    def ensure_can_manage_account
      authorize! Current.account, to: :manage?
    end

    def redirect_existing_user
      redirect_to root_path if Current.user
    end
end
