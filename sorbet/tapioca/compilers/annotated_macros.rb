# typed: true
# frozen_string_literal: true

require "prism"
require "rbs"
require "rbi"

module Tapioca
  module Dsl
    # Types for the methods Rails macros define, read from a trailing `#: Type` comment on the macro call, as
    # inline RBS does for `attr_reader`:
    #
    # ~~~rb
    # attribute :user #: User?
    # store_accessor :fields, :card_ids, :column_ids #: Array[String]?
    # class_attribute :push_targets, default: [] #: Array[singleton(Notification::PushTarget)]
    # ~~~
    #
    # Looks in the source files of the class and of the app modules it includes, so macros called in concerns'
    # `included` blocks count too.
    module AnnotatedMacros
      MODULE_NAME = Module.instance_method(:name)

      # { attribute name => RBI type } for the given macros
      #: (Module[top] constant, Array[Symbol] macros) -> Hash[String, String]
      def annotated_types(constant, macros)
        app_ancestors(constant).each_with_object({}) do |mod, types|
          path, _ = Object.const_source_location(MODULE_NAME.bind_call(mod).to_s)
          next unless path && File.exist?(path)

          result = Prism.parse_file(path)
          comments = result.comments.to_h { [ it.location.start_line, it.location.slice ] }

          calls(result.value).each do |call|
            next unless macros.include?(call.name)
            next unless (type = comments[call.location.end_line]&.[](/\A#:\s*(.+)\z/, 1))

            rbi_type = RBI::RBS::TypeTranslator.translate(::RBS::Parser.parse_type(type.strip)).to_rbi
            names_of(call).each { types[it] = rbi_type }
          end
        end
      end

      # Sets the type of the attribute methods (`name`, `name=`, `name_was`, ...) in the generated tree
      #: (RBI::Tree tree, Hash[String, String] types) -> void
      def apply_annotated_types(tree, types)
        return if types.empty?

        each_method(tree) do |method|
          name = method.name.delete_suffix("=")
          base = name.sub(/_(was|change|before_last_save|in_database)\z/, "").sub(/\Asaved_change_to_/, "")
          next unless (type = types[name] || types[base])
          next if method.name.end_with?("?")

          method.sigs.each do |sig|
            if method.name.end_with?("=")
              sig.params.map! { RBI::SigParam.new(it.name, type) }
              sig.return_type = type unless sig.return_type.to_s == "void"
            elsif name == method.name && !method.name.include?("change")
              sig.return_type = type
            end
          end
        end
      end

      private

      #: (Module[top] constant) -> Array[Module[top]]
      def app_ancestors(constant)
        roots = [ Rails.root.join("app").to_s, Rails.root.join("lib").to_s ]
        constant.ancestors.select do |mod|
          name = MODULE_NAME.bind_call(mod)
          path, _ = Object.const_source_location(name) if name
          path&.start_with?(*roots)
        rescue NameError
          false
        end
      end

      #: (Prism::Node node) -> Array[Prism::CallNode]
      def calls(node)
        found = []
        queue = [ node ]
        until queue.empty?
          current = queue.shift
          found << current if current.is_a?(Prism::CallNode) && current.receiver.nil?
          queue.concat(current.compact_child_nodes)
        end
        found
      end

      #: (Prism::CallNode call) -> Array[String]
      def names_of(call)
        arguments = (call.arguments&.arguments || []).grep(Prism::SymbolNode).map(&:unescaped)
        # `store_accessor :store, :key, ...` names the store first
        call.name == :store_accessor ? arguments.drop(1) : arguments
      end

      #: (RBI::Node node) { (RBI::Method) -> void } -> void
      def each_method(node, &block)
        case node
        when RBI::Method then yield node
        when RBI::Tree then node.nodes.each { each_method(it, &block) }
        end
      end
    end

    module Compilers
      # ActiveSupportCurrentAttributes, with `attribute` types from trailing `#:` comments
      #: [ConstantType = singleton(ActiveSupport::CurrentAttributes)]
      class AnnotatedCurrentAttributes < ActiveSupportCurrentAttributes
        include AnnotatedMacros

        # @override
        #: -> void
        def decorate
          super
          apply_annotated_types(root, annotated_types(constant, %i[ attribute ]))
        end
      end

      # ActiveRecordStore, with `store_accessor` types from trailing `#:` comments
      #: [ConstantType = singleton(ActiveRecord::Base)]
      class AnnotatedStore < ActiveRecordStore
        include AnnotatedMacros

        # @override
        #: -> void
        def decorate
          super
          apply_annotated_types(root, annotated_types(constant, %i[ store_accessor ]))
        end
      end

      # ActiveModelAttributes, with `attribute` types from trailing `#:` comments
      #: [ConstantType = singleton(ActiveModel::Attributes)]
      class AnnotatedModelAttributes < ActiveModelAttributes
        include AnnotatedMacros

        # @override
        #: -> void
        def decorate
          super
          apply_annotated_types(root, annotated_types(constant, %i[ attribute ]))
        end
      end

      # Typed accessors for `class_attribute`, `cattr_*`, `mattr_*` and `thread_mattr_*` annotated with a trailing
      # `#:` comment. Sorbet defines untyped ones for the `cattr`/`mattr` macros, but doesn't know `class_attribute`
      # or macros called in concerns' `included` blocks.
      #: [ConstantType = Module[top]]
      class AnnotatedClassAttributes < Compiler
        extend AnnotatedMacros

        MACROS = %i[
          class_attribute cattr_accessor cattr_reader mattr_accessor mattr_reader thread_mattr_accessor thread_cattr_accessor
        ]

        # @override
        #: -> void
        def decorate
          types = self.class.annotated_types(constant, MACROS)
          return if types.empty?

          root.create_path(constant) do |scope|
            types.each do |name, type|
              scope.create_method(name, return_type: type, class_method: true)
              scope.create_method("#{name}=", parameters: [ create_param("value", type: type) ], return_type: type, class_method: true)
              scope.create_method(name, return_type: type)
            end
          end
        end

        class << self
          # @override
          #: -> Enumerable[Module[top]]
          def gather_constants
            all_classes.select { |klass| name_of(klass) && annotated_types(klass, MACROS).any? }
          end
        end
      end
    end
  end
end
