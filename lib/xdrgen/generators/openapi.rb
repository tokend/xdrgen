module Xdrgen
  module Generators
    class Openapi < Xdrgen::Generators::Base
      OPENAPI_VERSION = '3.0.0'

      # Would not make ref to the definition of these types.
      # Instead will just write "type: <type>".
      # Add new types to this array in lowercase.
      LESS_INFO_TYPES = %w[accountid balanceid]

      def generate
        @already_rendered = []
        generated_path = "#{@namespace}_openapi_generated.yaml"
        @generated = @output.open(generated_path)

        render_top_matter
        @generated.indent { render_definitions @top }
      end

      private

      def render_definitions(node)
        node.definitions.each{|n| render_definition n}
        node.namespaces.each{|n| render_definitions n}
      end

      def render_definition(defn)
        if @already_rendered.include? name(defn)
          unless defn.is_a? AST::Definitions::Namespace
            $stderr.puts "warn: #{name(defn)} is defined twice. skipping"
          end

          return
        end

        render_nested_definitions(defn)

        @already_rendered << name(defn)

        case defn
        when AST::Definitions::Struct ;
          render_struct defn
        when AST::Definitions::Enum ;
          render_enum defn ;
        when AST::Definitions::Union ;
          render_union defn
        when AST::Definitions::Typedef ;
          render_typedef defn
        when AST::Definitions::Const ;
          render_const defn
        end
      end

      def render_nested_definitions(defn)
        return unless defn.respond_to? :nested_definitions
        defn.nested_definitions.each { |nested| render_definition nested }
      end

      def render_struct(struct)
        @generated.indent { @generated.puts "#{name struct}:" }
        @generated.indent(step = 2) do
          if struct.documentation.present?
            @generated.puts 'description: |-'
            @generated.indent { @generated.puts struct.documentation.join("\n")}
          end

          @generated.puts 'properties:'
          @generated.indent do
            struct.members.each do |member|
              render_struct_member member
            end
          end
        end
      end

      def render_struct_member(member)
        # TODO: Is it possible, that struct member does not have a name?
        @generated.puts "#{name member}:"
        @generated.indent do
          @generated.puts "#{reference(member.declaration.type)}"
          render_documentation_if_needed(member)
        end
      end

      def render_enum(enum)
        @generated.indent { @generated.puts "#{name enum}:" }

        # Generated enum description with names for values
        @generated.indent(step = 2) do
          @generated.puts 'description: |-'
          @generated.indent do
            enum.members.each do |m|
              @generated.puts "- \"#{(name m).underscore}\": #{m.value}"
              @generated.indent { @generated.puts(m.documentation.join("\n")) if m.documentation.present? }
            end
          end
        end

        # Generated enum values
        # For OpenAPI "values" are string names of enum elements
        @generated.indent(step = 2) do
          @generated.puts 'type: string'
          @generated.puts 'enum:'
          enum.members.each do |m|
            @generated.puts "- #{(name m).underscore}"
          end
        end
      end

      def render_union(union)
        # We need arms' types to be rendered, to references them later
        @generated.indent { render_union_arms(union) }

        @generated.indent do
          @generated.puts "#{name(union).underscore.camelize}:"
          @generated.indent do
            @generated.puts "type: object"
            if union.documentation.present?
              @generated.puts "description: |-"
              @generated.indent { @generated.puts union.documentation.join("\n") }
            end
            @generated.puts "oneOf:"
            @generated.indent do
              union.arms.each do |arm|
                if arm.is_a? Xdrgen::AST::Definitions::UnionDefaultArm
                  @generated.puts "- $ref: '#/components/schemas/#{name(arm.union)}ArmDefault'"
                  next
                end

                arm.cases.each do |kase|
                  # TODO: May be this can be done better than it is
                  @generated.puts "- $ref: '#/components/schemas/#{name(union)}Arm#{kase.value_s.underscore.camelize}'"
                end
              end
            end
          end
        end
      end

      def render_union_arms(union)
        union.arms.each do |arm|
          if arm.is_a?(Xdrgen::AST::Definitions::UnionDefaultArm)
            render_default_arm(arm)
          elsif arm.void?
            render_void_arm(arm)
          else
            render_common_arm(arm)
          end
        end
      end

      def render_common_arm(arm)
        # One arm can unify several discriminator values (fallthrough)
        # We render each case as a separate component
        arm.cases.each do |kase|
          render_union_case(arm.union, arm, kase)
        end
      end

      def render_union_case(union, arm, kase)
        @generated.puts '#{name(union)}#{kase.value_s.underscore.camelize}:'
        @generated.puts "#{name(union)}Arm#{kase.value_s.underscore.camelize}:"
        @generated.indent do
          @generated.puts("type: object")
          if kase.documentation.present?
            @generated.puts("description: |-")
            @generated.indent { @generated.puts kase.documentation.join("\n") }
          end
          @generated.puts("properties:")
          @generated.indent do
            @generated.puts("#{name(union.discriminant).downcase}:")
            @generated.indent do
              @generated.puts "type: string"
              @generated.puts "enum: [#{kase.value_s}]"
              if arm.documentation.present?
                @generated.puts "description: |-"
                @generated.puts arm.documentation.join("\n")
              end
            end
          @generated.puts "#{arm.name}:"
          @generated.indent { @generated.puts(reference(arm.type)) }
          end
        end
      end

      def render_void_arm(arm)
        @generated.puts("#{name(arm.union)}Arm#{arm.cases.first.value_s.underscore.camelize}:")
        @generated.indent do
          @generated.puts "type: object"
          @generated.puts "properties:"
          @generated.indent { @generated.puts "type:" }
          @generated.indent(step = 2) do
            @generated.puts "type: string"
            @generated.puts "enum:"
            @generated.indent do
              arm.cases.each { |kase| @generated.puts "- #{kase.value_s.underscore.camelize}"}
            end
          end
        end
      end

      def render_default_arm(arm)
        @generated.puts("#{name(arm.union)}ArmDefault:")
        @generated.indent do
          @generated.puts("type: object")
          @generated.puts("description: |-")
          @generated.indent do
            if arm.documentation.present?
              @generated.puts arm.documentation.join("\n")
            end
            @generated.puts "Note: Not generated properly yet, check .x file"
          end
        end
      end

      def render_top_matter
        @generated.puts <<~HEADER.strip_heredoc
          # Documentation is generated from:
          #
          #  #{@output.source_paths.join("\n#  ")}
          #
          # DO NOT EDIT or your changes may be overwritten
          components:
            schemas:
              Void:
                type: string
                nullable: true
        HEADER
      end

      # For debug purposes
      # Add this call before rendering definitions to see their xdr representation
      def render_source_comment(defn)
        return if defn.is_a? AST::Definitions::Namespace

        @generated.puts <<~XDR_DEF.strip_heredoc
          # #{name defn} is an XDR #{defn.class.name.demodulize} defines as:
          #
          #    #{defn.text_value.split("\n").join("\n#   ")}
          #
        XDR_DEF
      end

      def render_typedef(typedef)
        @generated.indent { @generated.puts("#{name typedef}:") }
        @generated.indent(step = 2) { @generated.puts("#{reference typedef.declaration.type}") }
      end

      # TODO: Dunno what to do with all of this ==================================================
      def render_fixed_size_opaque_type(decl); end
      def decl_string(decl); end
      def type_string(type); end
      def enum_case_name(name); end
      def name_string(name); end
      # ===========================================================================================

      # Finds a name of the syntax node
      def name(named)
        parent = name named.parent_defn if named.is_a?(AST::Concerns::NestedDefinition)

        base = named.respond_to?(:name) ? named.name : named.text_value

        "#{parent}#{base.underscore.camelize}"
      end

      # References syntax node's type
      # For primitive and built-in types will return "type: <type>"
      # For user-defined types will return "$ref: #/components/schema/<type>"
      def reference(type)
        baseReference = case type
        when AST::Typespecs::Bool
          "type: boolean"
        when AST::Typespecs::Double
          "type: double"
        when AST::Typespecs::Float
          "type: float"
        when AST::Typespecs::Hyper
          "type: long"
        when AST::Typespecs::Int
          "type: integer"
        when AST::Typespecs::Opaque
          "type: array"
        when AST::Typespecs::String
          "type: string"
        when AST::Typespecs::UnsignedHyper
          "type: uint64"
        when AST::Typespecs::UnsignedInt
          "type: uint32"
        when AST::Typespecs::Simple
          if type.primitive?
            "type: #{name(type).downcase}"
          elsif LESS_INFO_TYPES.include?(name(type).downcase)
            "type: #{name(type).underscore.camelize}"
          else
            "$ref: '#/components/schemas/#{name type}'"
          end
        when AST::Definitions::Base, AST::Concerns::NestedDefinition
          "$ref: '#/components/schemas/#{name type}'"
        else
          raise "Unknown reference type: #{type.class.name}, #{type.class.ancestors}"
        end
      end
    end
  end
end
