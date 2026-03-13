module Loomy
  module AST
    class Optimizer < Visitor
      def initialize(canvas)
        @canvas = canvas
        @width_stack = []
        @height_stack = []
      end

      def call
        visit(@canvas)
        @canvas
      end

      def visit_canvas(node)
        @width_stack.push(node.width)
        @height_stack.push(node.height)

        # Optimize children
        # We use map! to allow replacing nodes (though prune is different)
        # Standard visit iterates. Here we need to mutate the list.

        node.children.map! do |child|
          res = visit(child)
          # If visit returns :prune (or nil), we should handle it.
          # But map! replaces. So let's return the node if ok, nil if prune.
          res
        end
        node.children.compact!

        @width_stack.pop
        @height_stack.pop

        node
      end

      def visit_layer(node)
        parent_w, parent_h = @width_stack.last, @height_stack.last

        # Prune if no source is defined or if it is empty/invalid
        return nil if should_prune?(node)

        node.properties[:x] = resolve_dim(node.x, parent_w)
        node.properties[:y] = resolve_dim(node.y, parent_h)
        node.properties[:width] = resolve_dim(node.width, parent_w)
        node.properties[:height] = resolve_dim(node.height, parent_h)

        # Prune if fixed dimensions are 0
        return nil if node.width == 0 || node.height == 0

        node.effects.map! { |e| visit(e) }.compact!
        node
      end

      def visit_group(node)
        parent_w, parent_h = @width_stack.last, @height_stack.last

        node.properties[:x] = resolve_dim(node.x, parent_w)
        node.properties[:y] = resolve_dim(node.y, parent_h)
        node.properties[:width] = resolve_dim(node.width, parent_w)
        node.properties[:height] = resolve_dim(node.height, parent_h)

        @width_stack.push(node.width.is_a?(Numeric) ? node.width : parent_w)
        @height_stack.push(node.height.is_a?(Numeric) ? node.height : parent_h)

        node.children.map! { |child| visit(child) }.compact!

        @width_stack.pop
        @height_stack.pop

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

      def resolve_dim(value, total)
        return value unless value.is_a?(String) && value.end_with?("%")
        return value if total.nil?

        (total * (value.to_f / 100.0)).round
      end
    end
  end
end
