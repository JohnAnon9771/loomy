# frozen_string_literal: true

module Loomy
  module AST
    class Visitor
      def visit(node)
        node.accept(self)
      end

      def visit_node(node)
        # Default traversal
        node.children.each { |child| visit(child) }
      end

      def visit_canvas(node)
        visit_node(node)
      end

      def visit_layer(node)
        visit_node(node)
      end

      def visit_group(node)
        visit_node(node)
      end

      def visit_effect(node)
        # Effects usually don't have children, but if they did:
        visit_node(node)
      end

      # Specific effects can map to visit_effect or have their own
      def visit_displacement_effect(node) = visit_effect(node)
      def visit_lighting_effect(node) = visit_effect(node)
      def visit_blur_effect(node) = visit_effect(node)
      def visit_grayscale_effect(node) = visit_effect(node)
      def visit_color_adjustment_effect(node) = visit_effect(node)
    end
  end
end
