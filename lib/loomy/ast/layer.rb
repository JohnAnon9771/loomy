require_relative 'node'

module Loomy
  module AST
    class Layer < Node
      def source_type
        return :file     if properties[:source]
        return :solid    if properties[:solid]
        return :text     if properties[:text]
        return :gradient if properties[:gradient]
      end

      def source   = properties[:source]
      def solid    = properties[:solid]
      def text     = properties[:text]
      def gradient = properties[:gradient]
      def color    = properties[:color]
      def font     = properties[:font]
      def size     = properties[:size]

      def blend_mode = properties[:blend] || :over
      def x          = properties[:x] || 0
      def y          = properties[:y] || 0
      def width      = properties[:width]
      def height     = properties[:height]
      def fit        = properties[:fit]
      def gravity    = properties[:gravity] || :centre
      def trim       = properties[:trim]

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
