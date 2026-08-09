# frozen_string_literal: true

module Loomy
  module AST
    # Double dispatch over the node types. Layout and rendering are both walks
    # over the same small set of nodes, and going through #accept means adding a
    # node type without teaching every walker about it fails loudly here rather
    # than falling into a silent else-branch.
    #
    # There is deliberately no per-effect-class hook: effects differ in their
    # parameters, not in how the tree is walked, so one visit_effect is enough
    # and custom effect classes need no registration here.
    class Visitor
      def visit(node) = node.accept(self)

      def visit_node(node)
        raise NotImplementedError, "#{self.class} does not handle #{node.class}"
      end

      def visit_canvas(node) = visit_node(node)
      def visit_layer(node)  = visit_node(node)
      def visit_group(node)  = visit_node(node)
      def visit_stack(node)  = visit_node(node)
      def visit_effect(node) = visit_node(node)
    end
  end
end
