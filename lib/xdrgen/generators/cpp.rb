module Xdrgen
  module Generators

    class Cpp < Xdrgen::Generators::Base

      def generate
        @already_rendered = []
        path = "#{@namespace}_generated.h"
        out = @output.open(path)

        render_definitions(out, @top)
      end

      def render_definitions(out, node)
        node.definitions.each{|n| render_definition out, n }
        node.namespaces.each{|n| render_definitions out, n }
      end

      def render_definition(out, defn)
        if @already_rendered.include? name(defn)

          unless defn.is_a?(AST::Definitions::Namespace)
            $stderr.puts "warn: #{name(defn)} is defined twice.  skipping"
          end

          return
        end

        render_nested_definitions(out, defn)
        #render_source_comment(out, defn)

        @already_rendered << name(defn)

        case defn
        when AST::Definitions::Struct ;
          render_struct out, defn
        when AST::Definitions::Enum ;
          render_enum out, defn
        when AST::Definitions::Union ;
          render_union out, defn
        when AST::Definitions::Typedef ;
          render_typedef out, defn
        when AST::Definitions::Const ;
          render_const out, defn
        end
      end

      def render_nested_definitions(out, defn)
        return unless defn.respond_to? :nested_definitions
        defn.nested_definitions.each{|ndefn| render_definition out, ndefn}
      end

      def render_struct(out, struct)
        out.puts "struct #{name struct} : xdr_abstract \n{\n"
        out.indent do

          struct.members.each do |m|
            out.puts "#{reference(m.declaration.type)} #{name m};"
          end

        end
        out.puts "};"
        out.break
      end

      def reference(type)
        baseReference = case type
        when AST::Typespecs::Bool
          "bool"
        when AST::Typespecs::Double
          "float64"
        when AST::Typespecs::Float
          "float32"
        when AST::Typespecs::Hyper
          "int64_t"
        when AST::Typespecs::Int
          "int32_t"
        when AST::Typespecs::Opaque
          if type.fixed?
            "opaque_array<#{type.size}>"
          else
            "opaque_vec"
          end
        when AST::Typespecs::Quadruple
          raise "no quadruple support for c++"
        when AST::Typespecs::String
          "std::string"
        when AST::Typespecs::UnsignedHyper
          "uint64_t"
        when AST::Typespecs::UnsignedInt
          "uint32_t"
        when AST::Typespecs::Simple
          name type
        when AST::Definitions::Base
          name type
        when AST::Concerns::NestedDefinition
          name type
        else
          raise "Unknown reference type: #{type.class.name}, #{type.class.ancestors}"
        end

        case type.sub_type
        when :simple
          baseReference
        when :optional
          "pointer<#{baseReference}>"
        when :array
          is_named, size = type.array_size

          # if named, lookup the const definition
          if is_named
            size = name @top.find_definition(size)
          end

          "xarray<#{baseReference}, #{size}>"
        when :var_array
          "xvector<#{baseReference}>"
        else
          raise "Unknown sub_type: #{type.sub_type}"
        end

      end

      def render_enum(out, enum)
        # render the "enum"
        out.puts "enum class #{name enum} : std::int32_t \n{\n"
        out.indent do
          first_member = enum.members.first
          out.puts "#{name first_member} = #{first_member.value},"

          rest_members = enum.members.drop(1)
          rest_members.each do |m|
            out.puts "#{name m} = #{m.value},"
          end
        end
        out.puts "};"
      end


      def render_union(out, union)

        out.puts "struct #{name union} : xdr_abstract \n{\n"
        out.indent do
          out.puts "int32_t type_;"
          out.puts "union \n{"

          union.arms.each do |arm|
            next if arm.void?
            out.puts "#{reference arm.type} #{name arm};"
          end
          out.puts "};"
        end
        out.puts "};"
        out.break


      end

      def render_typedef(out, typedef)
        out.puts "using #{name typedef} = #{reference typedef.declaration.type};"


        # write sizing restrictions
        case typedef.declaration
        when Xdrgen::AST::Declarations::String
          #render_maxsize_method out, typedef, typedef.declaration.resolved_size
        when Xdrgen::AST::Declarations::Array
          unless typedef.declaration.fixed?
            #render_maxsize_method out, typedef, typedef.declaration.resolved_size
          end
        end

        return unless typedef.sub_type == :simple

        resolved = typedef.resolved_type

        case resolved
        when AST::Definitions::Enum
          #render_enum_typedef out, typedef, resolved
        when AST::Definitions::Union
          #render_union_typedef out, typedef, resolved
        end

        out.break
      end


      def render_const(out, const)
        out.puts "const #{name const} = #{const.value}"
        out.break
      end

      def name(named)
        named.name
      end
    end
  end
end
