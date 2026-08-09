# frozen_string_literal: true

module Loomy
  module DSL
    # Builds the root canvas. Its size and dpi come from the Loomy.render /
    # Loomy.generate options, so it exposes nesting only.
    class CanvasBuilder < NodeBuilder
      include Container

      private

      def node_class = AST::Canvas
    end
  end
end
