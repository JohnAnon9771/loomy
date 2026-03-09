module Loomy
  module AST
    class Stack < Node
      def direction = properties[:direction]
      def spacing   = properties[:spacing] || 0
      def align     = properties[:align]   # Cross-axis alignment
      def valign    = properties[:valign]  # Main-axis alignment/distribution

      def x      = properties[:x] || 0
      def y      = properties[:y] || 0
      def width  = properties[:width]
      def height = properties[:height]

      def effects
        @effects ||= []
      end

      def add_effect(effect)
        effects << effect
      end

      def accept(visitor) = visitor.visit_stack(self)
    end
  end
end
