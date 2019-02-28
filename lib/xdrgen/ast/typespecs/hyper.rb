module Xdrgen::AST::Typespecs
  class Hyper < Treetop::Runtime::SyntaxNode
    include Base

    def primitive?
      true
    end
  end
end