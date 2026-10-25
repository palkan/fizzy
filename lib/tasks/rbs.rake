namespace :rbs do
  desc "Install gem signatures from the RBS collection (.gem_rbs_collection)"
  task :collection do
    sh "bin/rbs collection install"
  end

  desc "Regenerate signatures for Rails models and route helpers (sig/rbs_rails)"
  task rails: "db:test:prepare" do
    # Generated against the test environment: development eagerly connects Solid Cache to a database it doesn't configure
    rm_rf "sig/rbs_rails"
    sh({ "RAILS_ENV" => "test" }, "bundle exec rbs_rails all")
  end

  desc "Regenerate declarations inline RBS can't express (sig/generated/inline.rbs)"
  task inline: :environment do
    require_relative "rbs/inline_gaps"

    path = Rails.root.join("sig/generated/inline.rbs")
    path.dirname.mkpath
    path.write Rbs::InlineGaps.new(Dir[Rails.root.join("{app,lib}/**/*.rb")].grep_v(%r{/lib/tasks/}).sort).to_rbs
    puts "Wrote #{path.relative_path_from(Rails.root)}"
  end

  desc "Regenerate all generated signatures"
  task generate: %i[ collection rails inline ]
end
