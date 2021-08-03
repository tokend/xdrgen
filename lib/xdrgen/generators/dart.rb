module Xdrgen
  module Generators
    class Dart < Xdrgen::Generators::Base
      def generate
        @already_rendered = []
        @existing_classes = []

        @file_extension = "dart"

        path = "xdr_types.#{@file_extension}"
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
        when AST::Definitions::Struct
          puts "Render: #{defn.name}"

          out = @out
          render_element "class", defn, "", " extends XdrEncodable ", out do
            render_struct defn, name, out
            out.puts "}"
            @existing_classes << name

            render_nested_definitions defn, defn.name
          end
        when AST::Definitions::Enum
          render_enum defn, name
        when AST::Definitions::Union
          render_union defn, name, ""
          @existing_classes << name
        when AST::Definitions::Typedef
          render_typedef defn, name
        end
      end

      def render_nested_definitions(defn, name, struct_name = "")
        return unless defn.respond_to? :nested_definitions

        defn.nested_definitions.each { |ndefn|
          name = name ndefn
          puts "Render-nested: #{name ndefn}"

          case ndefn
          when AST::Definitions::Struct
            out = @out
            render_element "class", ndefn, name, " extends XdrEncodable ", out do
              struct_name = "#{name_string name}#{name_string ndefn.name}"
              @existing_classes << struct_name

              render_struct ndefn, struct_name, out
              out.puts "}"

              render_nested_definitions ndefn, ndefn.name, struct_name = ""
            end
          when AST::Definitions::Enum
            render_enum ndefn, name
          when AST::Definitions::Union
            struct_name = "#{name_string name}#{name_string ndefn.name}"
            @existing_classes << struct_name
            render_union ndefn, name, struct_name
          when AST::Definitions::Typedef
            render_typedef ndefn, name
          end
        }
      end

      def render_element(type, element, prefix = "", post_name = "", out)
        name = name_string element.name
        render_source_comment element
        full_name = "#{prefix}#{name}"
        if @existing_classes.include? full_name
          full_name = "#{prefix}#{name}#{name}"
          @existing_classes << full_name
        end

        out.puts "#{type} #{full_name}#{post_name} {"
        out.indent do
          yield out
          out.unbreak
        end
      end

      def render_struct(struct, struct_name, out)
        out = @out
        out.indent do
          render_init_block(struct, struct_name)

          out.puts "@override toXdr(XdrDataOutputStream stream) {"
          out.indent do
            struct.members.each do |m|
              render_element_encode m, m.name
            end
          end
          out.puts "}"
          out.break

          out.break
        end

        out.unbreak
      end

      def render_enum(enum, name)
        out = @out

        out.puts "class #{name} extends XdrEncodable {"
        out.indent do
          enum.members.each do |em|
            out.puts "static const #{enum_case_name em.name} = #{em.value};"
          end

          out.puts "late int value;"
          out.puts "#{name}(this.value);"
          out.puts <<-EOS.strip_heredoc
          @override toXdr(XdrDataOutputStream stream) {
            value.toXdr(stream);
          }
          EOS

          out.break

          out.puts <<-EOS.strip_heredoc
          #{name}.fromXdr(XdrDataInputStream stream) {
            this.value = intFromXdr(stream);
          }
          EOS

          out.break
        end
        out.puts "}"
      end

      def render_union(union, name, struct_name)
        out = @out

        class_name = struct_name
        if struct_name.empty?
          class_name = name
        end

        out.puts "abstract class #{name} extends XdrEncodable {"

        out.indent do
          out.puts "late #{type_string union.discriminant.type} discriminant;"
          out.puts "#{name}(this.discriminant);"

          out.puts <<-EOS.strip_heredoc
                @override toXdr(XdrDataOutputStream stream) {
                    discriminant.toXdr(stream);
                }
                EOS


          out.break

          out.unbreak
          out.puts <<-EOS.strip_heredoc
                static #{name} fromXdr(XdrDataInputStream stream) {
                var discriminant = intFromXdr(stream);
  
                switch (discriminant) {
                   
                EOS
          out.break
          out.unbreak

          out.indent 2 do
            render_union_cases_from_xdr union, name
            out.puts "}"

            out.break
          end

          default_case = union.arms[0].cases[0]
          case_name = name_string union_case_name(default_case).downcase
          full_name = "#{name_string name}#{name_string case_name}"
          if @existing_classes.include? full_name
            full_name = "#{name_string name}#{name_string case_name}#{name_string case_name}"
          end
          out.puts "return #{full_name}.fromXdr(stream);"

          out.puts "}"
        end
        
        out.puts "}"
        foreach_union_case union do |union_case, arm|
          render_union_case union_case, arm, union, name, name, name
        end

        render_nested_definitions union, name

        out.break
      end

      def render_union_cases_from_xdr(union, union_name)
        @out.unbreak
        foreach_union_case union do |union_case, arm|
          out = @out
          out.puts "case #{type_string union.discriminant.type}.#{enum_case_name union_case_name union_case}:"
          out.indent do 
            name = name_string union_case_name(union_case).downcase
            full_name = "#{name_string union_name}#{name_string name}"

            if @existing_classes.include? full_name
              full_name = "#{name_string union_name}#{name_string name}#{name_string name}"
            end
            out.puts "return #{full_name}.fromXdr(stream);"
          end
        end
        @out.break
      end

      def render_union_case(union_case, arm, union, union_name, struct_name, parent_name)
        out = @out

        extending_class = union_name
        if !struct_name.empty?
          extending_class = struct_name
        end
        out.break
        name = name_string union_case_name(union_case).downcase
        full_name = "#{name_string union_name}#{name_string name}"

        if @existing_classes.include? full_name
          full_name = "#{name_string union_name}#{name_string name}#{name_string name}"
        end
        out.puts "class #{full_name} extends #{extending_class} {"
        out.indent do
          constructor_parameter = arm.void? ? "" : "this.#{arm.name}"
          out.puts "#{full_name}(#{constructor_parameter}) : super(#{type_string union.discriminant.type}(#{type_string union.discriminant.type}.#{enum_case_name union_case_name union_case}));"
        end
        unless arm.void?
          out.indent do
            out.puts "late #{union_case_data arm, struct_name, out} #{arm.name};"

            out.puts <<-EOS.strip_heredoc
                  @override toXdr(XdrDataOutputStream stream) {
                    super.toXdr(stream);
                  EOS
            out.indent do
              render_element_encode arm, arm.name
            end
            out.puts "}"

          end
        end
        out.indent do
          out.puts "#{full_name}.fromXdr(XdrDataInputStream stream): super(#{type_string union.discriminant.type}(#{type_string union.discriminant.type}.#{enum_case_name union_case_name union_case})){"
            out.indent do
              if arm.void? == false
                is_simple = arm.declaration.is_a?(AST::Declarations::Simple) or arm.declaration.is_a?(AST::Declarations::Optional)

                if is_simple_from_xdr arm.declaration
                  out.puts "var length = 0;"
                  if arm.declaration.is_a?(AST::Declarations::Array)

                    out.puts from_xdr arm.declaration, arm, false
                  else
                    out.puts from_xdr arm.declaration, arm
                  end
                else 
                  out.puts "this.#{arm.name} = #{union_case_data arm, struct_name, out}.fromXdr(stream);"
                end
              end
            end
            out.puts "}"
        end
        out.puts "}"
      end

      def union_case_data(arm, struct_name, oute)
        if ((arm.void?))
          ""
        else
          is_nested = arm.type.is_a?(AST::Concerns::NestedDefinition)
          is_struct = arm.type.is_a?(AST::Definitions::Struct) || arm.type.is_a?(AST::Definitions::Union)
          if !is_not_simple arm.declaration or arm.declaration.type.is_a?(AST::Definitions::NestedUnion)
            "#{decl_string arm.declaration}"
          else
            "#{name arm.type}#{name_string arm.name}"
          end
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
          out.puts "typedef #{name.upcase} = #{decl_string typedef.declaration};"

          case typedef.declaration
          when AST::Declarations::Array
            out.break
            out.puts "extension #{name}ToXdr on #{name.upcase} {"
            out.puts "toXdr(XdrDataOutputStream stream) {"
            out.indent do
              render_element_encode typedef, "this"
            end
            out.puts "}}"
          end
        end
      end

      def render_element_encode(element, name)
        out = @out

        if element.type.sub_type == :optional
          out.puts "if (#{name} != null) {"
          out.indent do
            out.puts "true.toXdr(stream);"
            case element.declaration
            when AST::Declarations::Array
              unless element.declaration.fixed?
                out.puts "#{name}?.length.toXdr(stream);"
              end
              out.puts <<-EOS.strip_heredoc
                    #{name}?.forEach((element) {
                      element.toXdr(stream);
                    });
                    EOS
            else
              out.puts "#{name}?.toXdr(stream);"
            end
          end
          out.puts <<-EOS.strip_heredoc
                } else {
                  false.toXdr(stream);
                }
                EOS
        else
          case element.declaration
          when AST::Declarations::Array
            unless element.declaration.fixed?
              out.puts "#{name}.length.toXdr(stream);"
            end
            out.puts <<-EOS.strip_heredoc
                    #{name}.forEach ((element) {
                      element.toXdr(stream);
                    });
                  EOS
          else
            out.puts "#{name}.toXdr(stream);"
          end
        end
      end

      def render_top_matter(out)
        out.puts <<-EOS.strip_heredoc
                // Automatically generated by xdrgen 
                // DO NOT EDIT or your changes may be overwritten
          
                import 'utils/dependencies.dart';
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
                class #{name} extends XdrFixedByteArray {
                  #{name}(Uint8List wrapped) : super(wrapped);
                  
                  @override
                  int size = #{decl.size};
                }
                EOS
        end

        name
      end

      def render_init_block(struct, name)
        out = @out
        out.indent do
          struct.members.each do |m|
            declaration = "late #{decl_string m.declaration} #{m.name};"

            if is_not_simple m.declaration or m.declaration.type.is_a?(AST::Definitions::NestedUnion)
              declaration = "late #{name m.type} #{m.name};"
            end

            out.puts "#{declaration}"
          end
          out.break

          out.puts "#{name_string name}("
          struct.members.each do |m|
            out.indent do
              out.puts "this.#{m.name}, "
            end
          end
          out.puts ");"
          out.break

          out.puts "#{name_string name}.fromXdr(XdrDataInputStream stream) {"
          out.puts "var length = 0;"

          struct.members.each do |m|
            out.indent do
              if m.declaration.is_a?(AST::Declarations::Array)
                out.puts from_xdr m.declaration, m, false
              elsif m.declaration.is_a?(AST::Declarations::Optional)
                out.puts <<-EOS.strip_heredoc
                if (boolFromXdr(stream)) {
                  #{from_xdr m.declaration, m}
                } else {
                  this.#{m.name} = null;
                }
                EOS

              else
                out.puts from_xdr m.declaration, m
              end
            end
          end
          out.puts "}"

          out.break
        end
      end

      def from_xdr(decl, source, with_declaration = true)
        declaration = "this.#{source.name} = "
        delimiter = ";"

        if !with_declaration
          declaration = ""
          delimiter = ""
        end

        case decl
        when AST::Declarations::Opaque
          if decl.fixed? 
            if with_declaration 
              if !source.declaration.is_a?(AST::Declarations::Array) 
                constructor = "#{decl_string source.declaration}"
                if constructor[constructor.length - 1] == '?'
                  constructor = constructor[0..constructor.length - 2]
                end
                "#{declaration}#{constructor}.fromXdr(stream)#{delimiter}"
              end 
            else
              "#{declaration}#{(name source.type.resolved_type).upcase}.fromXdr(stream)#{delimiter}"
            end
          elsif decl.fixed? and source.declaration.is_a?(AST::Declarations::Array)
            "#{declaration}#{type_string source.declaration.type}(opaqueFromXdr(stream))#{delimiter}"
          else
            "#{declaration}opaqueFromXdr(stream)#{delimiter}"
          end
        when AST::Declarations::String
          "#{declaration}stringFromXdr(stream)#{delimiter}"
        when AST::Declarations::Array
          <<-EOS.strip_heredoc
                length = intFromXdr(stream);
                #{source.name} = <#{type_string decl.type}>[];
                while (length > 0 ) {
                  #{source.name}.add(#{from_xdr_simple decl.type, decl, false});
                  length --;
                }
                
                EOS
        when AST::Declarations::Optional
          from_xdr_simple decl.type, source, with_declaration
        when AST::Declarations::Simple
          from_xdr_simple decl.type, source, with_declaration
        else
          raise "Unknown declaration type: #{decl.class.name}"
        end
      end

      def from_xdr_simple(type, source, with_declaration = true)
        decl = "this.#{source.name} = "
        delimiter = ";"
        if !with_declaration
          decl = ""
          delimiter = ""
        end

        case type
        when AST::Typespecs::Int
          "#{decl}intFromXdr(stream)#{delimiter}"
        when AST::Typespecs::UnsignedInt
          "#{decl}intFromXdr(stream)#{delimiter}"
        when AST::Typespecs::Hyper
          "#{decl}longFromXdr(stream)#{delimiter}"
        when AST::Typespecs::UnsignedHyper
          "#{decl}longFromXdr(stream)#{delimiter}"
        when AST::Typespecs::Float
          raise "cannot render Float in dart"
        when AST::Typespecs::Double
          raise "cannot render Double in dart"
        when AST::Typespecs::Quadruple
          raise "cannot render Quadruple in dart"
        when AST::Typespecs::Bool
          "#{decl}boolFromXdr(stream)#{delimiter}"
        when AST::Typespecs::Opaque
          "#{decl}opaqueFromXdr (stream)#{delimiter}"

        when AST::Typespecs::Simple
          if type.resolved_type.is_a?(AST::Definitions::Typedef)
            from_xdr type.resolved_type.declaration, source, with_declaration
          else
            if type.resolved_type.is_a?(AST::Definitions::Union)
              "#{decl}#{name type}.fromXdr(stream)#{delimiter}"
            else
              "#{decl}#{name type.resolved_type}.fromXdr(stream)#{delimiter}"
            end
          end
        when AST::Concerns::NestedDefinition
          "#{decl}#{name type}.fromXdr(stream)#{delimiter}"
        else
          raise "Unknown typespec: #{type.class.name}"
        end
      end

      def is_simple_from_xdr(decl)
        case decl
        when AST::Declarations::Opaque
          true
        when AST::Declarations::String
          true
        when AST::Declarations::Array
          true
        when AST::Declarations::Optional
          is_simple_from_xdr_type decl.type
        when AST::Declarations::Simple
          is_simple_from_xdr_type decl.type
        else
          raise "Unknown declaration type: #{decl.class.name}"
        end
      end

      def is_simple_from_xdr_type(type)
        case type
        when AST::Typespecs::Int
          true
        when AST::Typespecs::UnsignedInt
          true
        when AST::Typespecs::Hyper
          true
        when AST::Typespecs::UnsignedHyper
          true
        when AST::Typespecs::Float
          raise "cannot render Float in dart"
        when AST::Typespecs::Double
          raise "cannot render Double in dart"
        when AST::Typespecs::Quadruple
          raise "cannot render Quadruple in dart"
        when AST::Typespecs::Bool
          true
        when AST::Typespecs::Opaque
          true 

        when AST::Typespecs::Simple
          if type.resolved_type.is_a?(AST::Definitions::Typedef)
            true
          else
            false
          end
        when AST::Concerns::NestedDefinition
          false
        else
          raise "Unknown typespec: #{type.class.name}"
        end
      end

      def is_not_simple(decl)
        case decl
        when AST::Declarations::Opaque
          false
        when AST::Declarations::String
          false
        when AST::Declarations::Array
          false
        when AST::Declarations::Optional
          is_type_not_simple decl.type
        when AST::Declarations::Simple
          is_type_not_simple decl.type
        else
          raise "Unknown declaration type: #{decl.class.name}"
        end
      end

      def is_type_not_simple(type)
        case type
        when AST::Typespecs::Int
          false
        when AST::Typespecs::UnsignedInt
          false
        when AST::Typespecs::Hyper
          false
        when AST::Typespecs::UnsignedHyper
          false
        when AST::Typespecs::Float
          raise "cannot render Float in dart"
        when AST::Typespecs::Double
          raise "cannot render Double in dart"
        when AST::Typespecs::Quadruple
          raise "cannot render Quadruple in dart"
        when AST::Typespecs::Bool
          false
        when AST::Typespecs::Opaque
          false
        when AST::Typespecs::Simple
          false
        when AST::Definitions::NestedStruct
          true
        when AST::Definitions::NestedUnion
          false
        else
          raise "Unknown typespec: #{type.class.name}"
        end
      end

      def decl_string(decl)
        case decl
        when AST::Declarations::Opaque
          if decl.fixed?
            render_fixed_size_opaque_type decl
          else
            "Uint8List"
          end
        when AST::Declarations::String
          "String"
        when AST::Declarations::Array
          "List<#{type_string decl.type}>"
        when AST::Declarations::Optional
          "#{type_string(decl.type)}?"
        when AST::Declarations::Simple
          type_string(decl.type)
        else
          raise "Unknown declaration type: #{decl.class.name}"
        end
      end

      def type_string(type)
        case type
        when AST::Typespecs::Int
          "int"
        when AST::Typespecs::UnsignedInt
          "int"
        when AST::Typespecs::Hyper
          "Int64"
        when AST::Typespecs::UnsignedHyper
          "Int64"
        when AST::Typespecs::Float
          raise "cannot render Float in dart"
        when AST::Typespecs::Double
          raise "cannot render Double in dart"
        when AST::Typespecs::Quadruple
          raise "cannot render Quadruple in dart"
        when AST::Typespecs::Bool
          "bool"
        when AST::Typespecs::Opaque
          "Uint8List"
        when AST::Typespecs::Simple
          if type.resolved_type.is_a?(AST::Definitions::Typedef)
            "#{(name type.resolved_type).upcase}"
          else
            "#{name type.resolved_type}"
          end
        when AST::Concerns::NestedDefinition
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
