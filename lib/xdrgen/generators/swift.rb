module Xdrgen
  module Generators
    class Swift < Xdrgen::Generators::Base
      def generate
        @already_rendered = ["Int64", "Int32"]
        render_definitions(@top)
      end

      def render_definitions(node)
        node.namespaces.each{|n| render_definitions n }
        node.definitions.each(&method(:render_definition))
      end

      def render_definition(defn)
        case defn
        when AST::Definitions::Struct ;
          render_element "public struct", defn, ": XDRStruct" do |out|
            render_struct defn, out
            out.break
            render_nested_definitions defn, out
          end
        when AST::Definitions::Enum ;
          render_element "public enum", defn, ": Int32, XDREnum" do |out|
            render_enum defn, out
          end
        when AST::Definitions::Union ;
          render_element "public enum", defn, ": XDRDiscriminatedUnion" do |out|
            render_union defn, out
            out.break
            render_nested_definitions defn, out
          end
        when AST::Definitions::Typedef ;
          name = name_string defn.name
          unless @already_rendered.include? name
            render_file defn, name do |out|
              render_typedef defn, out
            end
          end
        end
      end

      def render_nested_definitions(defn, out)
        return unless defn.respond_to? :nested_definitions
        defn.nested_definitions.each{|ndefn|
          case ndefn
          when AST::Definitions::Struct ;
            name = name ndefn
            out.puts "public struct #{name}: XDRStruct {"
            out.indent do
              render_struct ndefn, out
              out.break
              render_nested_definitions ndefn , out
            end
            out.puts "}"
          when AST::Definitions::Enum ;
            name = name ndefn
            out.puts "public enum #{name}: Int32, XDREnum {"
            out.indent do
              render_enum ndefn, out
            end
            out.puts "}"
          when AST::Definitions::Union ;
            name = name ndefn
            out.puts "public enum #{name}: XDRDiscriminatedUnion {"
            out.indent do
              render_union ndefn, out
              out.break
              render_nested_definitions ndefn, out
            end
            out.puts "}"
          when AST::Definitions::Typedef ;
            out.indent do
              render_typedef ndefn, out
            end
          end
        }
      end

      def render_file(element, name)
        path = name + ".swift"
        out  = @output.open(path)
        render_top_matter out
        render_source_comment out, element

        yield out
      end

      def render_element(type, element, post_name="")
        name = name_string element.name
        render_file element, name do |out|
          out.puts "#{type} #{name}#{post_name} {"
          out.indent do
            yield out
            out.unbreak
          end
          out.puts "}"
        end
      end

      def render_struct(struct, out)
        struct.members.each do |m|
          out.puts "public var #{m.name}: #{decl_string m.declaration}"
        end
      end

      def render_union(union, out)
        foreach_union_case union do |union_case, arm|
          out.puts "case #{union_case_name union_case}(#{decl_string arm.declaration})"
        end

        out.break

        out.puts <<-EOS.strip_heredoc
        public var discriminant: Int32 {
          switch self {
        EOS
        out.indent do
          foreach_union_case union do |union_case, arm|
            out.puts "case .#{union_case_name union_case}: return #{type_string union.discriminant.type}.#{union_case_name union_case}.rawValue"
          end
        end
        out.puts <<-EOS.strip_heredoc
          }
        }
        EOS

        out.break

        out.puts <<-EOS.strip_heredoc
        public func toXDR() -> Data {
          var xdr = Data()
                
          xdr.append(self.discriminant.xdr)
                
          switch self {
        EOS
        out.indent do
          foreach_union_case union do |union_case, arm|
            if arm.void?
              out.puts "case .#{union_case_name union_case}(): xdr.append(Data())"
            else
              out.puts "case .#{union_case_name union_case}(let data): xdr.append(data.xdr)"
            end
          end
        end
        out.puts <<-EOS.strip_heredoc
          }

          return xdr
        }
        EOS
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
          enum_case_name union_case.value.name
        else
          enum_case_name union_case.value.value
        end
      end

      def render_typedef(typedef, out)
        out.puts "public typealias #{name_string typedef.name} = #{decl_string typedef.declaration}"
      end

      def render_fixed_size_opaque_type(decl)
        name = "XDRDataFixed#{decl.size}"
        unless @already_rendered.include? name
          @already_rendered << name

          render_file decl, name do |out|
            out.puts <<-EOS.strip_heredoc
            public struct #{name}: XDRDataFixed {
              public static var length: Int { return #{decl.size} }

              public var wrapped: Data
            
              public init() {
                  self.wrapped = Data()
              }
            }
            EOS
          end
        end
      end

      def render_enum(enum, out)
        enum.members.each do |em|
          out.puts "case #{enum_case_name em.name} = #{em.value}"
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
        when AST::Declarations::Void
          ""
        when AST::Declarations::Opaque ;
          if decl.fixed?
            render_fixed_size_opaque_type decl
            "XDRDataFixed#{decl.size}"
          else
            "Data"
          end
        when AST::Declarations::String ;
          "String"
        when AST::Declarations::Array ;
          if decl.fixed?
            "XDRArrayFixed<#{type_string decl.type}>"
          else
            "[#{type_string decl.type}]"
          end
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

      def enum_case_name(name)
        name.downcase.camelize :lower
      end

      def name_string(name)
        name.camelize
      end
    end
  end
end