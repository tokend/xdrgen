module Xdrgen
  module Generators
    class Dart < Xdrgen::Generators::Base
      def generate
        @already_rendered = []
        @file_extension = "dart"

        path = "XdrTypes.#{@file_extension}"

        @out = @output.open path
        render_top_matter @out

        @dependencies_path = "dependencies.#{@file_extension}"
        @dependencies_stream = @output.open @dependencies_path

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

          #out = @out
          file_path = "#{defn.name}.#{@file_extension}"
          @dependencies_stream.puts "export 'package:dart_wallet/xdr/generated/#{file_path}';"
          out_stream = @output.open file_path
          render_element "class", defn, "", " extends XdrEncodable ", out_stream do
            render_struct defn, name, out_stream
            out_stream.puts "}"

            render_nested_definitions defn, defn.name, out_stream
          end
        when AST::Definitions::Enum
          file_path = "#{defn.name}.#{@file_extension}"
          @dependencies_stream.puts "export 'package:dart_wallet/xdr/generated/#{file_path}';"
          out_stream = @output.open file_path
          render_enum defn, name, out_stream

          # render_element defn do
          #   render_enum defn, name
          # end
        when AST::Definitions::Union
          file_path = "#{defn.name}.#{@file_extension}"
          @dependencies_stream.puts "export 'package:dart_wallet/xdr/generated/#{file_path}';"
          out_stream = @output.open file_path
          render_top_matter out_stream
          render_union defn, name, out_stream

          # render_element defn do
          #   render_union defn, name
          # end
        when AST::Definitions::Typedef
          render_typedef defn, name

          # render_element defn do
          #   render_typedef defn, name
          # end
        end
      end

      def render_nested_definitions(defn, name, out)
        return unless defn.respond_to? :nested_definitions
        defn.nested_definitions.each { |ndefn|
          name = name ndefn

          case ndefn
          when AST::Definitions::Struct
            puts "Render-nested: #{ndefn.name}"
            out = @out
            render_element "class", ndefn, "", " extends XdrEncodable ", out do
              struct_name = "#{name_string name}"
              render_struct ndefn, struct_name, out
              out.puts "}"

              render_nested_definitions ndefn, ndefn.name, out
            end
          when AST::Definitions::Enum
            render_enum ndefn, name, out

            # render_element defn do
            #   render_enum defn, name
            # end
          when AST::Definitions::Union
            #file_path = "#{defn.name}.#{@file_extension}"
            #out_stream = @output.open file_path
            render_union ndefn, name, out

            # render_element defn do
            #   render_union defn, name
            # end
          when AST::Definitions::Typedef
            render_typedef ndefn, name

            # render_element defn do
            #   render_typedef defn, name
            # end
          end
        }
      end

      def render_element(type, element, prefix = "", post_name = "", out)
        #out = @out

        name = name_string element.name
        render_source_comment element

        out.puts "#{type} #{prefix}#{name}#{post_name} {"
        out.indent do
          yield out
          out.unbreak
        end
      end

      def render_struct(struct, struct_name, name)
        out = @out

        #   struct.members.each do |m|
        #     out.puts "#{struct.name}()"

        out.indent do
          render_init_block(struct, struct_name)

          out.puts "@override toXdr(XdrDataOutputStream stream) {"
          out.indent do
            struct.members.each do |m|
              render_element_encode m, m.name, out
            end
          end
          out.puts "}"
          out.break

          #render_decoder name
          out.break
        end

        out.unbreak
      end

      def render_enum(enum, name, out)
        #out = @out

        out.puts "class #{name} extends XdrEncodable {"
        out.indent do
          enum.members.each do |em|
            out.puts "static const #{enum_case_name em.name} = #{em.value};"
          end
          #render_decoder name

          out.puts "var value;"
          out.puts "#{name}(this.value);"
        end
        out.puts "}"
      end

      def render_union(union, name, out_stream)
        #out_stream = @out

        out_stream.puts "abstract class #{name} extends XdrEncodable {"

        out_stream.indent do
          out_stream.puts "#{type_string union.discriminant.type} discriminant;"
          out_stream.puts "#{name}(this.discriminant);"

          out_stream.puts <<-EOS.strip_heredoc
              @override toXdr(XdrDataOutputStream stream) {
                  discriminant.toXdr(stream);
              }
              EOS

          out_stream.break

          out_stream.break
          #render_decoder name

        end
        out_stream.unbreak
        out_stream.puts "}"

        foreach_union_case union do |union_case, arm|
          render_union_case union_case, arm, union, name
        end

        render_nested_definitions union, name, out_stream

        out_stream.break
      end

      def render_union_case(union_case, arm, union, union_name)
        name = name_string union_case_name(union_case).downcase
        file_path = "#{name}#{union_name}.#{@file_extension}"

        @dependencies_stream.puts "export 'package:dart_wallet/xdr/generated/#{file_path}';"

        out_stream = @output.open file_path
        render_top_matter out_stream

        out = out_stream

        out.break
        out.puts "class #{name} extends #{union_name} {"
        out.indent do
          out.puts "#{name}(#{union_case_data arm}) : super(#{type_string union.discriminant.type}(#{type_string union.discriminant.type}.#{enum_case_name union_case_name union_case}));"
        end
        unless arm.void?
          out.indent do
            #out.puts "#{name}(#{type_string union.discriminant.type}.#{enum_case_name union_case_name union_case})"

            out.puts "late #{union_case_data arm};"

            out.puts <<-EOS.strip_heredoc
                @override toXdr(XdrDataOutputStream stream) {
                  super.toXdr(stream);
                EOS
            out.indent do
              render_element_encode arm, arm.name, out
            end
            out.puts "}"
            #render_decoder name
          end
        end
        out.puts "}"
      end

      def union_case_data(arm)
        if arm.void?
          ""
        else
          "#{decl_string arm.declaration} #{arm.name}"
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
          out.puts "typedef #{name} = #{decl_string typedef.declaration};"

          case typedef.declaration
          when AST::Declarations::Array
            out.break
            out.puts "extension #{name}ToXdr on #{name} {"
            out.puts "toXdr(XdrDataOutputStream stream) {"
            out.indent do
              render_element_encode typedef, "this", out
            end
            out.puts "}}"
          end
        end
      end

      def render_element_encode(element, name, out)
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
        
              import 'package:dart_wallet/xdr/utils/dependencies.dart';

              import 'Memo.dart' as M;
              import 'XdrTypes.dart';
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
            out.puts "#{decl_string m.declaration} #{m.name};"
          end
          out.break

          out.puts "#{name_string struct.name}("
          struct.members.each do |m|
            out.indent do
              out.puts "this.#{m.name}, "
            end
          end
          out.puts ");"
          out.break
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
          "int"
        when AST::Typespecs::UnsignedHyper
          "int"
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
          "#{name type.resolved_type}"
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

      # def render_decoder(name)
      #   out = @out
      #   out.puts "companion object Decoder: XdrDecodable<#{name}> by ReflectiveXdrDecoder.wrapType()"
      # end
    end
  end
end
