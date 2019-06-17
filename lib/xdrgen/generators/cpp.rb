module Xdrgen
  module Generators

    class Cpp < Xdrgen::Generators::Base

      def generate
        @already_rendered = []
        header_path = "#{@namespace}_generated.h"
        header_out = @output.open(header_path)

        cpp_path = "#{@namespace}_generated.cpp"
        cpp_out = @output.open(cpp_path)

        render_definitions(header_out, cpp_out, @top)
      end

      def render_definitions(header_out, cpp_out, node)
        node.definitions.each{|n| render_definition header_out, cpp_out, n }
        node.namespaces.each{|n| render_definitions header_out, cpp_out, n }
      end

      def render_definition(header_out, cpp_out, defn)
        if @already_rendered.include? name(defn)

          unless defn.is_a?(AST::Definitions::Namespace)
            $stderr.puts "warn: #{name(defn)} is defined twice.  skipping"
          end

          return
        end

        render_nested_definitions(header_out, cpp_out, defn)
        #render_source_comment(out, defn)

        @already_rendered << name(defn)

        case defn
        when AST::Definitions::Struct ;
          render_struct header_out, cpp_out, defn
        when AST::Definitions::Enum ;
          render_enum header_out, cpp_out, defn
        when AST::Definitions::Union ;
          render_union header_out, cpp_out, defn
        when AST::Definitions::Typedef ;
          render_typedef header_out, cpp_out, defn
        when AST::Definitions::Const ;
          render_const header_out, cpp_out, defn
        end
      end

      def render_nested_definitions(header_out, cpp_out, defn)
        return unless defn.respond_to? :nested_definitions
        defn.nested_definitions.each{|ndefn| render_definition header_out, cpp_out, ndefn}
      end

      def render_struct(header_out, cpp_out, struct)
        struct.members.each do |m|
          try_render_defn(header_out, cpp_out, m)
        end

        header_out.puts "struct #{name struct} : xdr_abstract \n{\n"
        header_out.indent do

          struct.members.each do |m|

            header_out.puts "#{reference(m.declaration.type)} #{name m};"

          end

        end
        header_out.puts "};"
        header_out.break
      end

      def try_render_defn(header_out, cpp_out, defn)
        unless @already_rendered.include? name(defn)
          render_definition(header_out, cpp_out, defn)
        end
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

      def render_enum(header_out, cpp_out, enum)
        # render the "enum"
        header_out.puts "enum class #{name enum} : std::int32_t \n{\n"
        header_out.indent do
          first_member = enum.members.first
          header_out.puts "#{name first_member} = #{first_member.value},"

          rest_members = enum.members.drop(1)
          rest_members.each do |m|
            header_out.puts "#{name m} = #{m.value},"
          end
        end
        header_out.puts "};"
      end


      def render_union(header_out, cpp_out, union)

        methods_def = ""

        header_out.puts "struct #{name union} : xdr_abstract \n{\n"
        header_out.indent do
          header_out.puts "int32_t type_;"
          header_out.puts "union \n{"


          union.arms.each do |arm|
            next if arm.void?
            header_out.puts "#{reference arm.type} #{name arm};"

            methods_def << "#{reference arm.type}&\n#{name arm}();\n"

            cpp_out.puts "#{reference arm.type}&\n#{name union}::#{name arm}() \n{"
            cpp_out.puts " return #{name arm};\n}"
          end

          header_out.puts "};"
        end

        header_out.puts "#{reference union.discriminant.type}"
        header_out.puts "#{name union.discriminant}() const;"

        header_out.puts "#{name union}&\n#{name union.discriminant}(#{reference union.discriminant.type} d);"

        header_out.puts methods_def

        header_out.puts "};"
        header_out.break

        cpp_out.puts "#{reference union.discriminant.type}"
        cpp_out.puts "#{name union}::#{name union.discriminant}() const \n{"
        cpp_out.puts "return #{reference union.discriminant.type}(type_);\n}"

        cpp_out.puts "#{name union}&\n#{name union}::#{name union.discriminant}(#{reference union.discriminant.type} d)"
        cpp_out.puts "{\n  type_ = int32_t(d);\n  return *this;\n}"

        cpp_out.break
      end

      def render_typedef(header_out, cpp_out, typedef)
        header_out.puts "using #{name typedef} = #{reference typedef.declaration.type};"


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

        header_out.break
      end


      def render_const(header_out, cpp_out, const)
        header_out.puts "const #{name const} = #{const.value}"
        header_out.break
      end

      def name(named)
        result = named.name
        result = "#{name named.parent_defn}#{named.name.underscore.camelize}" if named.is_a?(AST::Concerns::NestedDefinition)

        "#{result}"
      end
    end
  end
end
