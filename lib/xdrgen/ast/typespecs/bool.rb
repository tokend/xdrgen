module Xdrgen::AST::Typespecs
  class Bool < Treetop::Runtime::SyntaxNode
    include Base

    def primitive?
      true
    end
  end
end