D = Steep::Diagnostic

target :app do
  # Generated (sig/rbs_rails, sig/generated) and hand-written (sig/shims) signatures.
  # Gem signatures come from the RBS collection (rbs_collection.yaml).
  signature "sig"

  # App code declares its types inline, with RBS annotations in comments
  check "app", "lib", inline: true
  ignore "lib/tasks", inline: true # Development tooling

  configure_code_diagnostics(D::Ruby.default)
end
