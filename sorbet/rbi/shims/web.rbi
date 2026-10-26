# typed: true

# Converted from sig/shims/web.rbs

class ApplicationCable::Connection
  sig { returns(::T.nilable(User)) }
  def current_user; end

  sig { params(value: ::T.nilable(User)).returns(::T.nilable(User)) }
  def current_user=(value); end
end

class ActionView::Base
  # Every helper in app/helpers, and the controllers' `helper_method`s, are available in views
  include ApplicationController::HelperMethods
end

module LoginHelper
  # Provided by the including controller or view
  sig { returns(T.untyped) }
  def main_app; end
end

module ActionView::ViewPaths::ClassMethods
  # Widens the community annotation: view paths also accept Pathnames
  sig { params(value: T.any(String, Pathname, T::Array[T.any(String, Pathname)])).void }
  def append_view_path(value); end
end
