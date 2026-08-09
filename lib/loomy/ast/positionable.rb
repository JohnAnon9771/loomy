# frozen_string_literal: true

module Loomy
  module AST
    # Geometry and placement properties shared by every node that occupies a box
    # inside its parent. Layer, Group and Stack each used to declare their own
    # near-identical copies of these readers.
    #
    # The values here are *declared* geometry straight from the DSL: they may be
    # nil, a percentage string, or :fill. Resolving them into concrete pixels is
    # Layout's job, not the node's.
    module Positionable
      def x = properties[:x] || 0
      def y = properties[:y] || 0
      def width  = properties[:width]
      def height = properties[:height]

      def align    = properties[:align]
      def valign   = properties[:valign]
      def anchor   = properties[:anchor]
      def offset_x = properties[:offset_x] || 0
      def offset_y = properties[:offset_y] || 0

      def blend_mode = properties[:blend] || :over
    end
  end
end
