require_relative 'node'

module Loomy
  module AST
    class Layer < Node
      def source
        properties[:source]
      end

      def blend_mode
        properties[:blend] || :over
      end

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

      def fit
        properties[:fit]
      end

      def gravity
        properties[:gravity] || :centre
      end

      def trim
        properties[:trim]
      end

      def effects
        @effects ||= []
      end

      def add_effect(effect)
        effects << effect
      end

      def accept(visitor)
        visitor.visit_layer(self)
      end
    end
  end
end
