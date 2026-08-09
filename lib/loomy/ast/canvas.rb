# frozen_string_literal: true

module Loomy
  module AST
    # Root of the tree. A canvas with no declared size is auto-sized from the
    # extent of its children during layout.
    class Canvas < Node
      def width  = properties[:size]&.at(0)
      def height = properties[:size]&.at(1)
      def dpi    = properties[:dpi]

      def accept(visitor) = visitor.visit_canvas(self)
    end
  end
end
