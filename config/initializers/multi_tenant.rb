Rails.application.configure do
  # Set on every code reload too, since a reload brings back the class attribute's default.
  config.to_prepare do
    Account.multi_tenant = ENV["MULTI_TENANT"] == "true" || Rails.application.config.x.multi_tenant.enabled == true
  end
end
