# typed: true
# frozen_string_literal: true

return unless defined?(ActiveRecord::Base)

require "tapioca/dsl/compilers/active_record_associations"

module Tapioca
  module Dsl
    module Compilers
      # Like ActiveRecordAssociations, but types a required `belongs_to` as present. Rails validates its presence
      # (`belongs_to_required_by_default`), so persisted records always have it. Optional and polymorphic
      # associations, and `has_one`, stay nilable.
      #
      # Replaces ActiveRecordAssociations, which `sorbet/tapioca/config.yml` excludes.
      #: [ConstantType = singleton(ActiveRecord::Base)]
      class RequiredAssociations < ActiveRecordAssociations
        private

        # @override
        #: (RBI::Scope klass, (String | Symbol) association_name, untyped reflection) -> void
        def populate_single_assoc_getter_setter(klass, association_name, reflection)
          super
          return unless required?(reflection)

          type = type_for(reflection)
          klass.nodes.grep(RBI::Method).select { [ association_name.to_s, "reload_#{association_name}" ].include?(it.name) }.each do |method|
            method.sigs.each { it.return_type = type }
          end
        end

        #: (untyped reflection) -> bool
        def required?(reflection)
          reflection.belongs_to? && !reflection.polymorphic? && !reflection.options[:optional] &&
            ActiveRecord::Base.belongs_to_required_by_default
        end
      end
    end
  end
end
