require_relative 'node'

module Loomy
  module AST
    class Canvas < Node
      def width
        properties[:size][0]
      end

      def height
        properties[:size][1]
      end

      def accept(visitor)
        visitor.visit_canvas(self)
      end
    end
  end
end
