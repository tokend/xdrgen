module Xdrgen::AST::Typespecs
  class UnsignedInt < Treetop::Runtime::SyntaxNode
    include Base

    def primitive?
      true
    end
  end
end