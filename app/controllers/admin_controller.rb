class AdminController < ApplicationController
  skip_authorization
  disallow_account_scope
  before_action :ensure_staff
end
