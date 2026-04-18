# frozen_string_literal: true

module Loomy
  module AST
    class Effect < Node
      def map_source
        properties[:map]
      end

      def accept(visitor)
        visitor.visit_effect(self)
      end
    end
  end
end
