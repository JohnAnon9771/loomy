# frozen_string_literal: true

module Loomy
  module AST
    # Geometry, placement and compositing shared by every node that occupies a
    # box inside its parent.
    #
    # These are *declared* values straight from the DSL: they may be nil, a
    # percentage string, or :fill. Resolving them into pixels is Layout's job,
    # not the node's.
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

      # How a finished node meets what is under it. Both belong here rather than
      # on Layer: a group has them too, and the renderer reads them together.
      def blend_mode = properties[:blend] || :over

      # `|| 1.0` is safe for `opacity: 0` -- 0 is truthy in Ruby, and nil only
      # ever means the property went undeclared, since AST::Node compacts.
      def opacity = properties[:opacity] || 1.0
    end
  end
end
