RbsRails.configure do |config|
  config.signature_root_dir = "sig/rbs_rails"

  # Migration checks iterate every configured database, including production-only ones
  config.check_db_migrations = false

  # Only generate signatures for the app's own models; gems ship (or lack) their own
  config.ignore_model_if do |klass|
    path, _ = Object.const_source_location(klass.name)
    path.nil? || !path.start_with?(Rails.root.join("app").to_s, Rails.root.join("lib").to_s)
  end
end
