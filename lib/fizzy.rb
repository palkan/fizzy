# typed: true

module Fizzy
  #: () -> bool
  def self.saas?
    return @saas if defined?(@saas)
    @saas = !!(((ENV["SAAS"] || File.exist?(File.expand_path("../../tmp/saas.txt", __FILE__))) && ENV["SAAS"] != "false"))
  end

  #: () -> DbAdapter
  def self.db_adapter
    @db_adapter ||= DbAdapter.new ENV.fetch("DATABASE_ADAPTER", saas? ? "mysql" : "sqlite")
  end

  #: () -> void
  def self.configure_bundle
    if saas?
      ENV["BUNDLE_GEMFILE"] = "Gemfile.saas"
    end
  end

  class DbAdapter
    #: (Object) -> void
    def initialize(name)
      @name = name.to_s #: String
    end

    #: () -> String
    def to_s
      @name
    end

    # Not using inquiry so that it works before Rails env loads.
    #: () -> bool
    def sqlite?
      @name == "sqlite"
    end
  end
end
