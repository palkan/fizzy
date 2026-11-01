# Loaded by Mutineer (see .mutineer.yml) once the app has booted, before it forks a process per mutant.

# The pending migrations check queries every database, cable included, which Mutineer
# reads as a test using a database its parallel workers share.
ActiveRecord.maintain_test_schema = false

# Mutineer loads a mutated file over the already-loaded app. Loading everything up front
# means a mutant reopens its class or concern, rather than reopening a constant whose original
# file hasn't been autoloaded yet, which would run that concern's `included` block twice.
Rails.application.eager_load!

# Reopening a model runs its class body again, declaring its enums a second time.
module MutineerEnumRedeclaration
  def enum(name, ...)
    @redeclaring_enum = defined_enums.key?(name.to_s)
    super
  ensure
    @redeclaring_enum = false
  end

  private
    def detect_enum_conflict!(...)
      super unless @redeclaring_enum
    end
end

ActiveRecord::Base.singleton_class.prepend(MutineerEnumRedeclaration)

# Reopening a class also redefines its constants, warning about each one on every mutant.
module MutineerConstantRedefinitionWarnings
  def warn(message, ...)
    super unless message.match?(/warning: (already initialized constant|previous definition of)/)
  end
end

Warning.singleton_class.prepend(MutineerConstantRedefinitionWarnings)
