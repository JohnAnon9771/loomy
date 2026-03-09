module Loomy
  module AST
    class Canvas < Node
      def width
        properties[:size]&.at(0)
      end

      def height
        properties[:size]&.at(1)
      end

      def accept(visitor)
        visitor.visit_canvas(self)
      end
    end
  end
end
