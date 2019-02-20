module Xdrgen::AST
  module Definitions
    class StructMember < Base
      delegate :name, to: :declaration
      delegate :type, to: :declaration

      def optional?
        declaration.is_a?(Declarations::Optional)
      end

      def documentation
        return '' if declaration.documentation_n.nil?

        declaration
          .documentation_n
          .text_value
          .split("\n")
          .select(&:present?)
          .map { |line| line.strip.sub(%r{^//:[\s]?}, '') }
          .join("\n")
      end
    end
  end
end