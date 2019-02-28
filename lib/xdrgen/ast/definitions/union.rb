module Xdrgen::AST
  module Definitions
    class Union < Base
      extend Memoist
      include Concerns::Named
      include Concerns::Namespace
      include Concerns::Contained

      delegate :discriminant, to: :union_body
      delegate :name, to: :discriminant, prefix:true
      delegate :arms, to: :union_body
      delegate :normal_arms, to: :union_body
      delegate :default_arm, to: :union_body

      memoize def discriminant_type
        return nil unless discriminant.type.is_a?(Identifier)

        root.find_definition discriminant.type.name
      end

      def resolved_case(kase)
        found = discriminant_type.members.find{|m| m.name == kase.value_s}
        raise "Case error:  #{kase} is not a member of #{discriminant_type.name}" if found.nil?
        found
      end

      def nested_definitions
        arms.
          map(&:declaration).
          reject{|d| d.is_a?(Declarations::Void)}.
          map(&:type).
          select{|d| d.is_a?(Concerns::NestedDefinition)}
      end

      # Checks whether there is union's arm with discriminator value of kase
      def case_processed?(kase)
        kase = kase.name unless kase.is_a?(String)

        arms.each do |arm|
          # Default arm does not have cases
          next if arm.is_a?(Xdrgen::AST::Definitions::UnionDefaultArm)

          arm.cases.each do |c|
            return true if c.value_s.casecmp?(kase)
          end
        end

        false
      end

      def default_arm
        arms.find { |arm| arm.is_a?(Xdrgen::AST::Definitions::UnionDefaultArm) }
      end
    end
  end
end
