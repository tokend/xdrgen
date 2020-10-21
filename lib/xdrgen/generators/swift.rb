module Xdrgen
  module Generators
    class Swift < Xdrgen::Generators::Base
      def generate
        @already_rendered = ["Int64", "Int32"]
        @file_extension = "swift"

        typedef_path = "Typedefs.#{@file_extension}"
        @typedefs = @output.open typedef_path
        render_top_matter @typedefs

        render_definitions @top
      end

      def render_definitions(node)
        node.namespaces.each { |n| render_definitions n }
        node.definitions.each { |n| render_definition n }
      end

      def render_definition(defn)
        case defn
        when AST::Definitions::Struct ;
          puts "Render: #{defn.name}"
          file_path = "#{defn.name}.#{@file_extension}"
          out = @output.open file_path
          render_top_matter out

          render_element "public struct", defn, ": XDRCodable", out do
            render_struct defn, out
            render_nested_definitions defn, out
          end
        when AST::Definitions::Enum ;
          puts "Render: #{defn.name}"
          file_path = "#{defn.name}.#{@file_extension}"
          out = @output.open file_path
          render_top_matter out

          render_element "public enum", defn, ": Int32, XDREnum", out do
            render_enum defn, out
          end
        when AST::Definitions::Union ;
          puts "Render: #{defn.name}"
          file_path = "#{defn.name}.#{@file_extension}"
          out = @output.open file_path
          render_top_matter out

          render_element "public enum", defn, ": XDRDiscriminatedUnion", out do
            render_union defn, out
            render_nested_definitions defn, out
          end
        when AST::Definitions::Typedef ;
          render_typedef defn
          @typedefs.break
        end
      end

      def render_nested_definitions(defn, out)
        return unless defn.respond_to? :nested_definitions
        defn.nested_definitions.each{|ndefn|
          case ndefn
          when AST::Definitions::Struct ;
            name = name ndefn
            out.puts "public struct #{name}: XDRCodable {"
            out.indent do
              render_struct ndefn, out
              out.break
              render_nested_definitions ndefn, out
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
              render_typedef ndefn
            end
          end
        }
      end

      def render_element(type, element, post_name="", out)
        name = name_string element.name
        render_source_comment element, out

        out.puts "#{type} #{name}#{post_name} {"
        out.indent do
          yield out
          out.unbreak
        end
        out.puts "}"
      end

      def render_struct(struct, out)
        struct.members.each do |m|
          out.puts "public var #{m.name}: #{decl_string m.declaration}"
        end
        out.break

        render_init_block struct, out

        out.break
        out.puts "public func toXDR() -> Data {"
        out.indent do
          out.puts "var xdr = Data()"
          out.break

          struct.members.each do |m|
            out.puts "xdr.append(self.#{m.name}.toXDR())"
          end

          out.break
          out.puts "return xdr"
        end
        out.puts "}"
        out.break

        out.break
        out.puts "public init(xdrData: inout Data) throws {"
        out.indent do
          struct.members.each do |m|
            case m.declaration
            when AST::Declarations::Optional ;
              out.puts <<-EOS.strip_heredoc
              if (try Bool(xdrData: &xdrData)) {
                self.#{m.name} = try #{type_string m.declaration.type}(xdrData: &xdrData)
              } else {
                self.#{m.name} = nil
              }
              EOS
            when AST::Declarations::Array ;
              if m.declaration.fixed?
                out.puts "self.#{m.name} = try #{decl_string m.declaration}(xdrData: &xdrData)"
              else
                out.puts <<-EOS.strip_heredoc
                let length#{m.name} = try Int32(xdrData: &xdrData)
                self.#{m.name} = #{decl_string m.declaration}()
                for _ in 1...length#{m.name} {
                  self.#{m.name}.append(try #{type_string m.declaration.type}(xdrData: &xdrData))
                }
                EOS
              end
            else
              out.puts "self.#{m.name} = try #{decl_string m.declaration}(xdrData: &xdrData)"
            end
          end
        end
        out.puts "}"
        out.break
      end

      def render_init_block(element, out)
        out.puts "public init("
        out.indent 2 do
          element.members.each_with_index do |member, index|
            out.puts "#{member.name}: #{decl_string member.declaration}#{(index != element.members.size - 1) ? "," : ") {"}"
          end
        end
        out.break

        out.indent do
          element.members.each do |member|
            out.puts "self.#{member.name} = #{member.name}"
          end
        end
        out.puts "}"
        out.break
      end

      def render_union(union, out)
        foreach_union_case union do |union_case, arm|
          if arm.void?
            out.puts "case #{union_case_name union_case}"
          else
            out.puts "case #{union_case_name union_case}(#{decl_string arm.declaration})"
          end
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

          xdr.append(self.discriminant.toXDR())

          switch self {
        EOS
        out.indent do
          foreach_union_case union do |union_case, arm|
            if arm.void?
              out.puts "case .#{union_case_name union_case}: xdr.append(Data())"
            else
              out.puts "case .#{union_case_name union_case}(let data): xdr.append(data.toXDR())"
            end
          end
        end
        out.puts <<-EOS.strip_heredoc
          }

          return xdr
        }
        EOS

        out.break

        out.puts <<-EOS.strip_heredoc
        public init(xdrData: inout Data) throws {
          let discriminant = try Int32(xdrData: &xdrData)

          switch discriminant {
        EOS
        out.indent do
          foreach_union_case union do |union_case, arm|
            if arm.void?
              out.puts "case #{type_string union.discriminant.type}.#{union_case_name union_case}.rawValue: self = .#{union_case_name union_case}"
            else
              out.puts "case #{type_string union.discriminant.type}.#{union_case_name union_case}.rawValue:"
              out.indent do
                m = arm
                case m.declaration
                when AST::Declarations::Optional ;
                  out.puts <<-EOS.strip_heredoc
                  var data #{type_string m.declaration.type}
                  if (try Bool(xdrData: &xdrData)) {
                    data = try #{type_string m.declaration.type}(xdrData: &xdrData)
                  } else {
                    data = nil
                  }
                  EOS
                when AST::Declarations::Array ;
                  if m.declaration.fixed?
                    out.puts "data = try #{decl_string m.declaration}(xdrData: &xdrData)"
                  else
                    out.puts <<-EOS.strip_heredoc
                    let length#{m.name} = try Int32(xdrData: &xdrData)
                    var data = #{decl_string m.declaration}()
                    for _ in 1...length#{m.name} {
                      data.append(try #{type_string m.declaration.type}(xdrData: &xdrData))
                    }
                    EOS
                  end
                else
                  out.puts "let data = try #{decl_string m.declaration}(xdrData: &xdrData)"
                end
                out.puts "self = .#{union_case_name union_case}(data)"
              end
            end
          end
        end
        out.puts <<-EOS.strip_heredoc
          default:
            throw XDRErrors.unknownEnumCase
          }
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

      def render_typedef(typedef)
        out = @typedefs

        render_source_comment typedef, out

        name = name_string typedef.name
        unless @already_rendered.include? name
          out.puts "public typealias #{name} = #{decl_string typedef.declaration}"
        end
      end

      def render_fixed_size_array_type(decl)
        name = "XDRArrayFixed#{decl.size}"

        unless @already_rendered.include? name
          @already_rendered << name

          out = @output.open "#{name}.#{@file_extension}"
          render_top_matter out
          out.puts <<-EOS.strip_heredoc
          /// Fixed length byte array
          public struct #{name}<WrappedElement: XDRCodable>: XDRArrayFixed {
            public typealias Element = WrappedElement

            public static var length: Int { return #{decl.size} }

            public var wrapped: [WrappedElement]

            public init() {
                self.wrapped = [WrappedElement]()
            }
          }
          EOS
        end
      end

      def render_fixed_size_opaque_type(decl)
        name = "XDRDataFixed#{decl.size}"

        unless @already_rendered.include? name
          @already_rendered << name

          out = @output.open "#{name}.#{@file_extension}"
          render_top_matter out
          out.puts <<-EOS.strip_heredoc
          /// Fixed length byte array
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

      def render_source_comment(defn, out)
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
            render_fixed_size_array_type decl
            "XDRArrayFixed#{decl.size}<#{type_string decl.type}>"
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
