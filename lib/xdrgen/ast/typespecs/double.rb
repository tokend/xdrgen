module Xdrgen::AST::Typespecs
  class Double < Treetop::Runtime::SyntaxNode
    include Base

    def primitive?
      true
    end
  end
end