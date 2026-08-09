# frozen_string_literal: true

module Loomy
  module DSL
    # Builds the root canvas. Everything it carries comes from the
    # Loomy::CANVAS_OPTIONS half of the Loomy.render / Loomy.generate options,
    # so it exposes nesting only.
    class CanvasBuilder < NodeBuilder
      include Container

      private

      def node_class = AST::Canvas
    end
  end
end
