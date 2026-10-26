# typed: true
# frozen_string_literal: true

return unless defined?(ActiveSupport::Concern)

require "prism"

module Tapioca
  module Dsl
    module Compilers
      # Declares the modules a concern mixes in from its `included do ... end` (or `prepended`) block,
      # which Sorbet doesn't see:
      #
      # ~~~rb
      # module Card::Searchable
      #   extend ActiveSupport::Concern
      #
      #   included do
      #     include ::Searchable
      #     include Rails.application.routes.url_helpers
      #   end
      # end
      # ~~~
      #
      # ~~~rbi
      # module Card::Searchable
      #   include ::Searchable
      #   include ::GeneratedUrlHelpersModule
      # end
      # ~~~
      #
      # The block runs in the including class, so the mixins end up there. Declaring them on the concern is
      # equivalent for type checking, because the class includes the concern.
      #: [ConstantType = Module[top]]
      class IncludedBlockMixins < Compiler
        URL_HELPERS = "Rails.application.routes.url_helpers"

        # @override
        #: -> void
        def decorate
          mixins = self.class.mixins_of(constant)
          return if mixins.empty?

          root.create_path(constant) do |scope|
            mixins.each do |method, name|
              case method
              when :include then scope.create_include(name)
              when :extend then scope.create_extend(name)
              end
            end
          end
        end

        class << self
          # @override
          #: -> Enumerable[Module[top]]
          def gather_constants
            all_modules.select do |mod|
              name_of(mod) && !mod.singleton_class? && !mod.is_a?(Class) &&
                ActiveSupport::Concern > mod.singleton_class && mixins_of(mod).any?
            end
          end

          # [method, module name] pairs from the concern's `included`/`prepended` blocks
          #: (Module[top] mod) -> Array[[Symbol, String]]
          def mixins_of(mod)
            @mixins ||= {}
            @mixins[mod] ||= begin
              path, _ = Object.const_source_location(mod.name.to_s)
              app_source?(path) ? scan(Prism.parse_file(path).value, mod, []) : []
            rescue NameError
              []
            end
          end

          private

          # Only the app's concerns: gems' RBIs come from `tapioca gems`
          #: (String? path) -> bool
          def app_source?(path)
            !path.nil? && path.start_with?(Rails.root.join("app").to_s, Rails.root.join("lib").to_s)
          end

          #: (Prism::Node node, Module[top] mod, Array[String] nesting) -> Array[[Symbol, String]]
          def scan(node, mod, nesting)
            statements_of(node).flat_map do |statement|
              case statement
              when Prism::ModuleNode, Prism::ClassNode
                scan(statement.body, mod, nesting + [ statement.constant_path.slice ])
              when Prism::CallNode
                if %i[included prepended].include?(statement.name) && statement.block.is_a?(Prism::BlockNode) &&
                    resolve(nesting.last.to_s, nesting[0...-1]) == mod
                  block_mixins(statement.block.body, nesting)
                else
                  []
                end
              else
                []
              end
            end
          end

          #: (Prism::Node? body, Array[String] nesting) -> Array[[Symbol, String]]
          def block_mixins(body, nesting)
            statements_of(body).grep(Prism::CallNode).select { it.receiver.nil? && %i[include extend].include?(it.name) }.flat_map do |call|
              (call.arguments&.arguments || []).filter_map do |argument|
                if argument.slice == URL_HELPERS
                  [ call.name, "::GeneratedUrlHelpersModule" ]
                elsif argument.is_a?(Prism::ConstantReadNode) || argument.is_a?(Prism::ConstantPathNode)
                  if (target = resolve(argument.slice, nesting)) && target.name
                    [ call.name, "::#{target.name}" ]
                  end
                end
              end
            end
          end

          #: (Prism::Node? node) -> Array[Prism::Node]
          def statements_of(node)
            case node
            when Prism::ProgramNode then node.statements.body
            when Prism::StatementsNode then node.body
            when nil then []
            else [ node ]
            end
          end

          # Approximates Ruby's lexical constant lookup from within the given nesting
          #: (String name, Array[String] nesting) -> Module[top]?
          def resolve(name, nesting)
            return Object.const_get(name.delete_prefix("::")) if name.start_with?("::")

            nesting.size.downto(0).each do |depth|
              return Object.const_get([ *nesting.first(depth), name ].join("::"))
            rescue NameError
              next
            end

            nil
          end
        end
      end
    end
  end
end
