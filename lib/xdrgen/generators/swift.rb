module Xdrgen
  module Generators
    class Swift < Xdrgen::Generators::Base
      def generate
        render_lib
      end

      def render_lib
        template = IO.read(__dir__ + "/swift/xdr.erb")
        result = ERB.new(template).result binding
        @output.write  "Utils/Xdr.swift", result
      end
    end
  end
end