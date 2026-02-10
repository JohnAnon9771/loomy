require_relative 'node'

module Loomy
  module AST
    class Group < Node
      def x
        properties[:x] || 0
      end

      def y
        properties[:y] || 0
      end

      def width
        properties[:width]
      end

      def height
        properties[:height]
      end

      def blend_mode
        properties[:blend] || :over
      end

      def effects
        @effects ||= []
      end

      def add_effect(effect)
        effects << effect
      end

      def accept(visitor)
        visitor.visit_group(self)
      end
    end
  end
end
