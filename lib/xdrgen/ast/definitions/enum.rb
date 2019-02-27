module Xdrgen::AST
  module Definitions
    class Enum < Base
      extend Memoist
      include Concerns::Named
      include Concerns::Contained

      memoize def members
        results = [enum_body.first_member_n]
        enum_body.additional_members_n.elements.each do |n|
          results.push n.enum_member
        end
        results
      end

      def member_by_name(name)
        members.each do |m|
          return m if m.name.casecmp?(name)
        end
      end
    end
  end
end