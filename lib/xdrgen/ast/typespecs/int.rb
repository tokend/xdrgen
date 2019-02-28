module Xdrgen::AST::Typespecs
  class Int < Treetop::Runtime::SyntaxNode
    include Base

    def primitive?
      true
    end
  end
end