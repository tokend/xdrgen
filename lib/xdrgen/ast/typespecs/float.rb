module Xdrgen::AST::Typespecs
  class Float < Treetop::Runtime::SyntaxNode
    include Base

    def primitive?
      true
    end
  end
end