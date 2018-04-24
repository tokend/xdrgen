module Xdrgen
  module Generators
    class Swift < Xdrgen::Generators::Base
      def generate
        render_definitions(@top)
      end

      def render_definitions(node)
        node.namespaces.each{|n| render_definitions n }
        node.definitions.each(&method(:render_definition))
      end

      def render_definition(defn)
        case defn
        when AST::Definitions::Enum ;
          render_element "enum", defn, ": XDREnum, Int32" do |out|
            render_enum defn, out
          end
        when AST::Definitions::Typedef ;
          render_typedef defn
        end
      end

      def render_element(type, element, post_name="")
        path = element.name.camelize + ".swift"
        name = name_string element.name
        out  = @output.open(path)
        render_top_matter out
        render_source_comment out, element

        out.puts "#{type} #{name} #{post_name} {"
        out.indent do
          yield out
          out.unbreak
        end
        out.puts "}"
      end

      def render_typedef(element)
        path = element.name.camelize + ".swift"
        name = name_string element.name
        out  = @output.open(path)
        render_top_matter out
        render_source_comment out, element

        out.puts "typealias #{name} = #{decl_string element.declaration}"
        out.break
      end

      def render_enum(enum, out)
        out.balance_after /,[\s]*/ do
          enum.members.each do |em|
            out.puts "case #{em.name} = #{em.value}"
          end
        end
        out.break
      end

      def render_top_matter(out)
        out.puts <<-EOS.strip_heredoc
          // Automatically generated by xdrgen 
          // DO NOT EDIT or your changes may be overwritten

          import Foundation
        EOS
        out.break
      end

      def render_source_comment(out, defn)
        return if defn.is_a?(AST::Definitions::Namespace)

        out.puts <<-EOS.strip_heredoc
        // === xdr source ============================================================

        EOS

        out.puts "//  " + defn.text_value.split("\n").join("\n//  ")

        out.puts <<-EOS.strip_heredoc

        //  ===========================================================================
        EOS
      end

      def decl_string(decl)
        case decl
        when AST::Declarations::Opaque ;
          "Data"
        when AST::Declarations::String ;
          "String"
        when AST::Declarations::Array ;
          "[#{type_string decl.type}]"
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
          "Int32"
        when AST::Typespecs::UnsignedInt ;
          "UInt32"
        when AST::Typespecs::Hyper ;
          "Int64"
        when AST::Typespecs::UnsignedHyper ;
          "UInt64"
        when AST::Typespecs::Float ;
          raise "cannot render Float in Swift"
        when AST::Typespecs::Double ;
          raise "cannot render Double in Swift"
        when AST::Typespecs::Quadruple ;
          raise "cannot render Quadruple in Swift"
        when AST::Typespecs::Bool ;
          "Bool"
        when AST::Typespecs::Opaque ;
          "Data"
        when AST::Typespecs::Simple ;
          name type.resolved_type
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

      def name_string(name)
        name.camelize
      end
    end
  end
end