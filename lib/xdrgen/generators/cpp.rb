module Xdrgen
  module Generators

    class Cpp < Xdrgen::Generators::Base

      def generate
        @already_rendered = []
        header_path = "#{@namespace}_generated.h"
        header_out = @output.open(header_path)

        cpp_path = "#{@namespace}_generated.cpp"
        cpp_out = @output.open(cpp_path)

        render_top_matter header_out, cpp_out
        render_definitions(header_out, cpp_out, @top)
        render_bottom_matter header_out, cpp_out
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
          try_render_type_defn(header_out, cpp_out, m.declaration.type)
        end

        header_out.puts "struct #{name struct} : xdr_abstract \n{\n"
        header_out.indent do

          struct.members.each do |m|

            header_out.puts "#{reference(m.declaration.type)} #{name m};"

          end

          header_out.puts "bool\noperator==(xdr_abstract const& other) const override;\n"
          header_out.puts "bool\noperator<(xdr_abstract const& other) const override;\n"
          header_out.puts "#{name struct}() {}"
          header_out.puts "#{name struct}("
          first = true
          struct.members.each do |m|
            if first
              first = false
            else
              header_out.puts ","
            end
            header_out.puts "#{reference(m.declaration.type)} const& #{name m}"
          end
          header_out.puts ") : "
          first = true
          struct.members.each do |m|
            if first
              first = false
            else
              header_out.puts ","
            end
            header_out.puts "#{name m}(#{name m})"
          end
          header_out.puts "{}"
          header_out.puts "~#{name struct}() {}\n"
          header_out.puts "private:"
          header_out.puts "bool\nfrom_bytes(unmarshaler& u) override;\n"
          header_out.puts "bool\nto_bytes(marshaler& m) override;\n"

          cpp_out.puts "bool\n#{name struct}::from_bytes(unmarshaler& u)\n{"
          struct.members.each do |m|
            cpp_out.puts "bool ok#{name m} = u.from_bytes(#{name m});"
            cpp_out.puts "if (!ok#{name m})\n{"
            cpp_out.puts "return false;\n}\n"
          end
          cpp_out.puts "return true;"
          cpp_out.puts "}"

          cpp_out.puts "bool\n#{name struct}::to_bytes(marshaler& m)\n{"
          struct.members.each do |m|
            cpp_out.puts "bool ok#{name m} = m.to_bytes(#{name m});"
            cpp_out.puts "if (!ok#{name m})\n{"
            cpp_out.puts "return false;\n}\n"
          end
          cpp_out.puts "return true;"
          cpp_out.puts "}"

          cpp_out.puts "bool\n#{name struct}::operator==(xdr_abstract const& other_abstract) const\n{"
          cpp_out.puts "if (typeid(*this) != typeid(other_abstract))\n{\nreturn false;\n}"
          cpp_out.puts "auto& other = dynamic_cast<#{name struct} const&>(other_abstract);"
          cpp_out.puts "return true "
          struct.members.each do |m|
            cpp_out.puts "&& (#{name m} == other.#{name m}) "
          end
          cpp_out.puts ";}"

          cpp_out.puts "bool\n#{name struct}::operator<(xdr_abstract const& other_abstract) const\n{"
          cpp_out.puts "if (typeid(*this) != typeid(other_abstract))\n{\nthrow std::runtime_error(\"unexpected operator< invoke\");\n}"
          cpp_out.puts "auto& other = dynamic_cast<#{name struct} const&>(other_abstract);"

          struct.members.each do |m|
            cpp_out.puts "if (#{name m} < other.#{name m}) return true;"
            cpp_out.puts "if (other.#{name m} < #{name m}) return false;"
          end
          cpp_out.puts "return false;\n}"

        end
        header_out.puts "};"
        header_out.break
      end

      def try_render_type_defn(header_out, cpp_out, type)
        return unless type&.respond_to? :name

        defn = @top.find_definition(name type)
        return if defn.nil?

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
            "opaque_vec<>"
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
        try_render_type_defn header_out, cpp_out, union.discriminant.type

        union.arms.each do |m|
          next if m.void?
          try_render_type_defn(header_out, cpp_out, m.type)
        end

        methods_def = ""
        const_methods_def = ""

        header_out.puts "struct #{name union} : xdr_abstract \n{\n"
        header_out.puts "private:"
        header_out.indent do
          header_out.puts "int32_t type_;"
          header_out.puts "union \n{"

          union.arms.each do |arm|
            next if arm.void?
            header_out.puts "#{reference arm.type} #{name arm}_;"

            methods_def << "#{reference arm.type}&\n#{name arm}();\n"
            const_methods_def << "#{reference arm.type} const&\n#{name arm}() const;\n"

            cpp_out.puts "#{reference arm.type}&\n#{name union}::#{name arm}() \n{"
            cpp_out.puts " return #{name arm}_;\n}"

            cpp_out.puts "#{reference arm.type} const&\n#{name union}::#{name arm}() const \n{"
            cpp_out.puts " return #{name arm}_;\n}"
          end

          header_out.puts "};"
        end

        header_out.puts "bool\nfrom_bytes(unmarshaler& u) override;\n"
        header_out.puts "bool\nto_bytes(marshaler& m) override;\n"

        header_out.puts "public:"
        header_out.puts "bool\noperator==(xdr_abstract const& other) const override;\n"
        header_out.puts "bool\noperator<(xdr_abstract const& other) const override;\n"
        header_out.puts "#{name union}() {}"
        header_out.puts "~#{name union}() {}\n"
        header_out.puts "#{name union}(#{name union} const& other) : type_(other.type_) {"
        switch_for header_out, union, "type_" do |arm|
          "#{(arm.void? ? "break;" : ("#{name arm}_(other.#{name arm}_);"))};"
        end

        header_out.puts "#{reference union.discriminant.type}"
        header_out.puts "#{name union.discriminant}() const;"

        header_out.puts "#{name union}&\n#{name union.discriminant}(#{reference union.discriminant.type} d);"

        header_out.puts methods_def
        header_out.puts const_methods_def

        header_out.puts "};"
        header_out.break

        cpp_out.puts "#{reference union.discriminant.type}"
        cpp_out.puts "#{name union}::#{name union.discriminant}() const \n{"
        cpp_out.puts "return #{reference union.discriminant.type}(type_);\n}"

        cpp_out.puts "#{name union}&\n#{name union}::#{name union.discriminant}(#{reference union.discriminant.type} d)"
        cpp_out.puts "{\n  type_ = int32_t(d);\n  return *this;\n}"

        cpp_out.puts "bool\n#{name union}::from_bytes(unmarshaler& u)\n{"
        cpp_out.puts "bool ok = u.from_bytes(type_);"
        cpp_out.puts "if (!ok)\n{"
        cpp_out.puts "return false;\n}\n"
        switch_for cpp_out, union, "type_" do |arm|
          "return #{(arm.void? ? "true" : ("u.from_bytes(#{name arm}_)"))};"
        end
        cpp_out.puts "return false;"
        cpp_out.puts "}"


        cpp_out.puts "bool\n#{name union}::to_bytes(marshaler& m)\n{"
        cpp_out.puts "bool ok = m.to_bytes(type_);"
        cpp_out.puts "if (!ok)\n{"
        cpp_out.puts "return false;\n}\n"
        switch_for cpp_out, union, "type_" do |arm|
          "return #{(arm.void? ? "true" : ("m.to_bytes(#{name arm}_)"))};"
        end
        cpp_out.puts "return false;"
        cpp_out.puts "}"

        cpp_out.puts "bool\n#{name union}::operator==(xdr_abstract const& other_abstract) const\n{"
        cpp_out.puts "if (typeid(*this) != typeid(other_abstract))\n{\nreturn false;\n}"
        cpp_out.puts "auto& other = dynamic_cast<#{name union} const&>(other_abstract);"
        cpp_out.puts "if (this->type_ != other.type_)\n{\nreturn false;\n}"
        switch_for cpp_out, union, "type_" do |arm|
          "return #{(arm.void? ? "true" : ("(this->#{name arm}_ == other.#{name arm}_)"))};"
        end
        cpp_out.puts "}"

        cpp_out.puts "bool\n#{name union}::operator<(xdr_abstract const& other_abstract) const\n{"
        cpp_out.puts "if (typeid(*this) != typeid(other_abstract))\n{\nthrow std::runtime_error(\"unexpected operator< invoke\");\n}"
        cpp_out.puts "auto& other = dynamic_cast<#{name union} const&>(other_abstract);"
        cpp_out.puts "if (this->type_ < other.type_) return true;"
        cpp_out.puts "if (other.type_ < this->type_) return false;"
        switch_for cpp_out, union, "type_" do |arm|
          "return #{(arm.void? ? "false" : ("(this->#{name arm}_ < other.#{name arm}_)"))};"
        end
        cpp_out.puts "}"

        cpp_out.break
      end

      def switch_for(out, union, ident)
        out.puts "switch (#{reference union.discriminant.type}(#{ident}))\n{"

        union.normal_arms.each do |arm|
          arm.cases.each do |c|

            value = if c.value.is_a?(AST::Identifier)
                      member = union.resolved_case(c)
                      "#{name union.discriminant_type}::#{name member}"
                    else
                      c.value.text_value
                    end

            out.puts "    case #{value}:"
            out.puts "      #{yield arm}"
          end
        end

        if union.default_arm.present?
          arm = union.default_arm
          out.puts "    default:"
          out.puts "      #{yield arm}"
        end

        out.puts "}"
      end

      def render_typedef(header_out, cpp_out, typedef)
        try_render_type_defn header_out, cpp_out, typedef.declaration.type

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

      def render_top_matter(header_out, cpp_out)
        header_out.puts "#pragma once"
        header_out.puts "#include \"lib/xdrpp/src/types.h\""
        header_out.puts "#include \"lib/xdrpp/src/xdr_abstract.h\"\n"
        header_out.puts "using namespace xdr;\n"
        header_out.puts "namespace stellar \n{\n"

        cpp_out.puts "#include \"xdr_generated.h\""
        cpp_out.puts "#include \"lib/xdrpp/src/unmarshaler.h\""
        cpp_out.puts "#include \"lib/xdrpp/src/marshaler.h\""
        cpp_out.puts "#include \"lib/xdrpp/src/unmarshaler.t.hpp\""
        cpp_out.puts "#include \"lib/xdrpp/src/marshaler.t.hpp\"\n"
        cpp_out.puts "using namespace xdr;\n"
        cpp_out.puts "namespace stellar \n{\n"
      end

      def render_bottom_matter(header_out, cpp_out)
        header_out.puts "\n}"
        cpp_out.puts "\n}"
      end
    end
  end
end
