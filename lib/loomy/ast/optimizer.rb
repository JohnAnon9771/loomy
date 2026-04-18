module Loomy
  module AST
    class Optimizer < Visitor
      def initialize(canvas)
        @canvas = canvas
      end

      def call
        visit(@canvas)
        @canvas
      end

      def visit_canvas(node)
        node.children.map! { |child| visit(child) }.compact!
      end

      def visit_layer(node)
        return nil if should_prune?(node)

        node.effects.map! { |e| visit(e) }.compact!
        node
      end

      def visit_group(node)
        node.children.map! { |child| visit(child) }.compact!
        node.effects.map! { |e| visit(e) }.compact!
        node
      end

      def visit_stack(node)
        node.children.map! { |child| visit(child) }.compact!
        node.effects.map! { |e| visit(e) }.compact!
        node
      end

      # No-op optimizations for effects

      def visit_blur_effect(node)
        node.radius <= 0 ? nil : node
      end

      def visit_color_adjustment_effect(node)
        node.brightness == 1.0 && node.contrast == 1.0 ? nil : node
      end

      def visit_lighting_effect(node)
        node.strength <= 0 ? nil : node
      end

      def visit_effect(node)
        node
      end

      private

      def should_prune?(node)
        case node.source_type
        when nil then true
        when :text then node.text.nil? || node.text.to_s.empty?
        when :file then node.source.nil? || node.source.to_s.empty?
        else false
        end
      end
    end
  end
end
