module Xdrgen
  module Generators
    class Kotlin < Xdrgen::Generators::Base
      def generate
        @already_rendered = []
        @file_extension = "kt"

        path = "XdrTypes.#{@file_extension}"
        @out = @output.open path
        render_top_matter @out

        render_definitions @top
      end

      def render_definitions(node)
        node.namespaces.each { |n| render_definitions n }
        node.definitions.each { |n| render_definition n }
      end

      def render_definition(defn)
        name = name_string defn.name

        case defn
        when AST::Definitions::Struct ;
          render_element defn do
            render_struct defn, name
          end
        when AST::Definitions::Enum ;
          render_element defn do
            render_enum defn, name
          end
        when AST::Definitions::Union ;
          render_element defn do
            render_union defn, name
          end
        when AST::Definitions::Typedef ;
          render_element defn do
            render_typedef defn, name
          end
        end
      end

      def render_nested_definitions(defn)
        return unless defn.respond_to? :nested_definitions
        defn.nested_definitions.each { |ndefn|
          name = name ndefn

          case ndefn
          when AST::Definitions::Struct ;
            render_struct ndefn, name
          when AST::Definitions::Enum ;
            render_enum ndefn, name
          when AST::Definitions::Union ;
            render_union ndefn, name
          when AST::Definitions::Typedef ;
            render_typedef ndefn, name
          end
        }
      end

      def render_element(defn)
        out = @out

        render_source_comment defn
        yield
        out.break
      end

      def render_struct(struct, name)
        out = @out

        out.puts "open class #{name}("
        out.indent 2 do
          struct.members.each_with_index do |m, index|
            out.puts "var #{m.name}: #{decl_string m.declaration}#{(index == struct.members.size - 1) ? "" : ","}"
          end
        end
        out.indent do
          out.puts ") : XdrEncodable {"
          out.break
          out.puts "override fun toXdr(stream: XdrDataOutputStream) {"
          out.indent do
            struct.members.each do |m|
              render_element_encode m, m.name
            end
          end
          out.puts "}"
          out.break

          render_nested_definitions struct
        end

        out.unbreak
        out.puts "}"
      end

      def render_enum(enum, name)
        out = @out

        out.puts "public enum class #{name}(val value: kotlin.Int): XdrEncodable {"
        out.indent do
          enum.members.each do |em|
            out.puts "#{enum_case_name em.name}(#{em.value}),"
          end
          out.puts ";"
          out.break
          out.puts <<-EOS.strip_heredoc
          override fun toXdr(stream: XdrDataOutputStream) {
              value.toXdr(stream)
          }
          EOS
        end
        out.puts "}"
      end

      def render_union(union, name)
        out = @out

        out.puts "abstract class #{name}(val discriminant: #{type_string union.discriminant.type}): XdrEncodable {"
        out.indent do
          out.puts <<-EOS.strip_heredoc
          override fun toXdr(stream: XdrDataOutputStream) {
              discriminant.toXdr(stream)
          }
          EOS
          foreach_union_case union do |union_case, arm|
            render_union_case union_case, arm, union, name
          end
          out.break

          render_nested_definitions union
        end
        out.unbreak
        out.puts "}"
      end

      def render_union_case(union_case, arm, union, union_name)
        out = @out

        out.break
        out.puts "open class #{name_string union_case_name(union_case).downcase}#{union_case_data arm}: #{union_name}(#{type_string union.discriminant.type}.#{enum_case_name union_case_name union_case})#{arm.void? ? "" : " {"}"
        unless arm.void?
          out.indent do
            out.puts <<-EOS.strip_heredoc
            override fun toXdr(stream: XdrDataOutputStream) {
              super.toXdr(stream)
            EOS
            out.indent do
              render_element_encode arm, arm.name
            end
            out.puts "}"
          end
          out.puts "}"
        end
      end

      def union_case_data(arm)
        if arm.void?
          ""
        else
          "(var #{arm.name}: #{decl_string arm.declaration})"
        end
      end

      def foreach_union_case(union)
        union.arms.each do |arm|
          next if arm.is_a?(AST::Definitions::UnionDefaultArm)

          arm.cases.each do |union_case|
            yield union_case, arm
          end
        end
      end

      def union_case_name(union_case)
        if union_case.value.is_a?(AST::Identifier)
          union_case.value.name
        else
          union_case.value.value
        end
      end

      def render_typedef(typedef, name)
        out = @out

        unless @already_rendered.include? name
          out.puts "public typealias #{name} = #{decl_string typedef.declaration}"

          case typedef.declaration
          when AST::Declarations::Array ;
            out.break
            out.puts "fun #{name}.toXdr(stream: XdrDataOutputStream) {"
            out.indent do
              render_element_encode typedef, "this"
            end
            out.puts "}"
          end
        end
      end

      def render_element_encode(element, name)
        out = @out

        if element.type.sub_type == :optional
          out.puts "if (#{name} != null) {"
          out.indent do
            out.puts "true.toXdr(stream)"
            case element.declaration
            when AST::Declarations::Array ;
              unless element.declaration.fixed?
                out.puts "#{name}?.size.toXdr(stream)"
              end
              out.puts <<-EOS.strip_heredoc
              #{name}?.forEach {
                it.toXdr(stream)
              }
              EOS
            else
              out.puts "#{name}?.toXdr(stream)"
            end
          end
          out.puts <<-EOS.strip_heredoc
          } else {
            false.toXdr(stream)
          }
          EOS
        else
          case element.declaration
          when AST::Declarations::Array ;
            unless element.declaration.fixed?
              out.puts "#{name}.size.toXdr(stream)"
            end
            out.puts <<-EOS.strip_heredoc
              #{name}.forEach {
                it.toXdr(stream)
              }
            EOS
          else
            out.puts "#{name}.toXdr(stream)"
          end
        end

      end

      def render_top_matter(out)
        out.puts <<-EOS.strip_heredoc
          // Automatically generated by xdrgen 
          // DO NOT EDIT or your changes may be overwritten

          package #{@namespace}

          import #{@namespace}.utils.*
        EOS
        out.break
      end

      def render_source_comment(defn)
        out = @out

        return if defn.is_a?(AST::Definitions::Namespace)

        out.puts <<-EOS.strip_heredoc
        // === xdr source ============================================================

        EOS

        out.puts "//  " + defn.text_value.split("\n").join("\n//  ")

        out.puts <<-EOS.strip_heredoc

        //  ===========================================================================
        EOS
      end

      def render_fixed_size_opaque_type(decl)
        name = "XdrByteArrayFixed#{decl.size}"

        unless @already_rendered.include? name
          @already_rendered << name

          out = @output.open "#{name}.#{@file_extension}"
          render_top_matter out
          out.puts <<-EOS.strip_heredoc
          /// Fixed length byte array 
          class #{name}(byteArray: kotlin.ByteArray): XdrFixedByteArray(byteArray) {
              override val size: Int
                  get() = #{decl.size}
          }
          EOS
        end

        name
      end

      def decl_string(decl)
        case decl
        when AST::Declarations::Opaque ;
          if decl.fixed?
            render_fixed_size_opaque_type decl
          else
            "kotlin.ByteArray"
          end
        when AST::Declarations::String ;
          "kotlin.String"
        when AST::Declarations::Array ;
          "kotlin.Array<#{type_string decl.type}>"
        when AST::Declarations::Optional ;
          "#{type_string(decl.type)}?"
        when AST::Declarations::Simple ;
          type_string(decl.type)
        else
          raise "Unknown declaration type: #{decl.class.name}"
        end
      end

      def type_string(type)
        case type
        when AST::Typespecs::Int ;
          "kotlin.Int"
        when AST::Typespecs::UnsignedInt ;
          "kotlin.Int"
        when AST::Typespecs::Hyper ;
          "kotlin.Long"
        when AST::Typespecs::UnsignedHyper ;
          "kotlin.Long"
        when AST::Typespecs::Float ;
          raise "cannot render Float in Kotlin"
        when AST::Typespecs::Double ;
          raise "cannot render Double in Kotlin"
        when AST::Typespecs::Quadruple ;
          raise "cannot render Quadruple in Kotlin"
        when AST::Typespecs::Bool ;
          "kotlin.Boolean"
        when AST::Typespecs::Opaque ;
          "kotlin.ByteArray"
        when AST::Typespecs::Simple ;
          "#{@namespace}.#{name type.resolved_type}"
        when AST::Concerns::NestedDefinition ;
          name type
        else
          raise "Unknown typespec: #{type.class.name}"
        end
      end

      def name(named)
        parent = name named.parent_defn if named.is_a?(AST::Concerns::NestedDefinition)
        result = named.name.camelize

        "#{parent}#{result}"
      end

      def enum_case_name(name)
        name
      end

      def name_string(name)
        name.camelize
      end
    end
  end
end