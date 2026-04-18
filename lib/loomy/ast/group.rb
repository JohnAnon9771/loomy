# frozen_string_literal: true

module Loomy
  module AST
    class Group < Node
      def x      = properties[:x] || 0
      def y      = properties[:y] || 0
      def width  = properties[:width]
      def height = properties[:height]

      def align      = properties[:align]
      def valign     = properties[:valign]
      def anchor     = properties[:anchor]
      def offset_x   = properties[:offset_x] || 0
      def offset_y   = properties[:offset_y] || 0

      def blend_mode = properties[:blend] || :over

      def effects
        @effects ||= []
      end

      def add_effect(effect)
        effects << effect
      end

      def accept(visitor) = visitor.visit_group(self)
    end
  end
end
