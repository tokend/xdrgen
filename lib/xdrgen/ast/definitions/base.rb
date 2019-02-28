module Xdrgen::AST::Definitions
  class Base < Treetop::Runtime::SyntaxNode

    def sub_type
      :simple
    end

    def documentation
      return [] unless respond_to?(:documentation_n) && documentation_n.present?

      documentation_n
        .text_value
        .split("\n")
        .select(&:present?)
        .map { |line| line.strip.sub(%r{^//:[\s]?}, '') }
    end
  end
end