# frozen_string_literal: true

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
        node
      end

      def visit_layer(node)
        return nil if should_prune?(node)
        return nil if invalid_dimensions?(node)

        node.effects.map! { |e| visit(e) }.compact!
        node
      end

      def visit_group(node)
        node.children.map! { |child| visit(child) }.compact!
        node.effects.map! { |e| visit(e) }.compact!
        node
      end

      def visit_blur_effect(node)
        node.radius <= 0 ? nil : node
      end

      def visit_color_adjustment_effect(node)
        node.brightness == 1.0 && node.contrast == 1.0 ? nil : node
      end

      def visit_displacement_effect(node)
        return nil if node.scale <= 0
        return nil if node.intensity <= 0
        return nil if node.from_mask? && node.from_mask.nil?
        return nil if !node.from_mask? && node.map_path.nil?
        node
      end

      def visit_lighting_effect(node)
        return nil if node.strength <= 0
        return nil if node.from_mask? && node.from_mask.nil?
        return nil if !node.from_mask? && node.map_path.nil?
        node
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

      def invalid_dimensions?(node)
        (node.width.is_a?(Numeric) && node.width.zero?) ||
        (node.height.is_a?(Numeric) && node.height.zero?)
      end
    end
  end
end