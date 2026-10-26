# typed: true
# frozen_string_literal: true

return unless defined?(ActiveRecord::Base)

module Tapioca
  module Dsl
    module Compilers
      # Relations delegate to their model's class methods, so `board.cards.closed_recently` works when
      # `Card.closed_recently` is a class method. Tapioca declares scopes on relations, but not other class methods.
      # This adds the model's own public class methods and those of its concerns' `ClassMethods`, with their types,
      # to `Model::GeneratedRelationMethods` and `Model::GeneratedAssociationRelationMethods`, which relations of the model include.
      #: [ConstantType = singleton(ActiveRecord::Base)]
      class RelationClassMethods < Compiler
        # @override
        #: -> void
        def decorate
          concerns = class_methods_modules
          methods = own_class_methods
          return if concerns.empty? && methods.empty?

          # Copied rather than included: ClassMethods modules require the model's singleton class as an ancestor
          definitions = concerns.flat_map { |mod| mod.public_instance_methods(false).sort.map { mod.instance_method(it) } } + methods

          root.create_path(constant) do |model|
            # Relations include the first, association relations and collection proxies the second
            %w[ GeneratedRelationMethods GeneratedAssociationRelationMethods ].each do |module_name|
              model.create_module(module_name) do |relation_methods|
                definitions.each { create_method_from_def(relation_methods, it) }
              end
            end
          end
        end

        class << self
          # @override
          #: -> Enumerable[Module[top]]
          def gather_constants
            descendants_of(::ActiveRecord::Base).reject(&:abstract_class?).select { app_source?(it) }
          end

          #: (Module[top] mod) -> bool
          def app_source?(mod)
            path, _ = Object.const_source_location(name_of(mod).to_s)
            !path.nil? && path.start_with?(Rails.root.join("app").to_s, Rails.root.join("lib").to_s)
          rescue NameError
            false
          end
        end

        private

        # Concerns' ClassMethods the model is extended with, from the app
        #: -> Array[Module[top]]
        def class_methods_modules
          inherited = constant.superclass.singleton_class.ancestors
          constant.singleton_class.ancestors.select do |mod|
            name = name_of(mod)
            name&.end_with?("::ClassMethods") && !inherited.include?(mod) && self.class.app_source?(mod)
          end
        end

        # Public class methods defined in the model's own file
        #: -> Array[UnboundMethod]
        def own_class_methods
          constant.singleton_methods(false).sort.filter_map do |name|
            method = constant.method(name)
            # Methods with signatures are wrapped by sorbet-runtime, so look at the original's location
            path, _ = (T::Utils.signature_for_method(method)&.method || method).source_location
            method.unbind if path && path == Object.const_source_location(name_of(constant).to_s)&.first &&
              constant.singleton_class.public_method_defined?(name)
          end
        end
      end
    end
  end
end
