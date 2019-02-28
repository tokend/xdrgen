module Xdrgen::AST::Typespecs
  class UnsignedHyper < Treetop::Runtime::SyntaxNode
    include Base

    def primitive?
      true
    end
  end
end