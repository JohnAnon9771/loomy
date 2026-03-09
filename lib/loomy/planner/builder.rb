require "loomy/ast/visitor"
require "loomy/ops/base"
require "loomy/ops/load"
require "loomy/ops/solid"
require "loomy/ops/text"
require "loomy/ops/gradient"
require "loomy/ops/trim"
require "loomy/ops/resize"
require "loomy/ops/effect_op"
require "loomy/ops/pipeline"

module Loomy
  module Planner
    class Builder < AST::Visitor
      def initialize
        @width_stack = []
        @height_stack = []
      end

      def build(canvas)
        @width_stack = [canvas.width]
        @height_stack = [canvas.height]
        visit(canvas)
      end

      def visit_canvas(node)
        pipeline = Ops::Pipeline.new(
          background_width: node.width,
          background_height: node.height
        )

        node.children.each do |layer|
          op_tree = visit(layer)
          pipeline.add_layer(op_tree, layer_properties(layer)) if op_tree
        end

        pipeline
      end

      def visit_group(node)
        parent_w, parent_h = @width_stack.last, @height_stack.last
        
        @width_stack.push(node.width || parent_w)
        @height_stack.push(node.height || parent_h)

        pipeline = Ops::Pipeline.new(
          background_width: node.width || parent_w,
          background_height: node.height || parent_h
        )

        node.children.each do |child|
          op_tree = visit(child)
          pipeline.add_layer(op_tree, layer_properties(child)) if op_tree
        end

        @width_stack.pop
        @height_stack.pop

        apply_effects(pipeline, node.effects)
      end

      def visit_layer(node)
        op = build_base_op(node)
        op = Ops::Trim.new(input: op) if node.trim && node.source_type == :file
        
        # Only use Ops::Resize for fixed numeric target sizes.
        # If any axis is semantic (like :fill), defer to Pipeline resolution.
        if node.width.is_a?(Numeric) && node.height.is_a?(Numeric)
          op = Ops::Resize.new(input: op, width: node.width, height: node.height, fit: node.fit)
        elsif node.width.is_a?(Numeric)
          op = Ops::Resize.new(input: op, width: node.width, height: nil, fit: node.fit)
        elsif node.height.is_a?(Numeric)
          op = Ops::Resize.new(input: op, width: nil, height: node.height, fit: node.fit)
        end

        apply_effects(op, node.effects)
      end

      private

      def layer_properties(layer)
        {
          x:        layer.x,
          y:        layer.y,
          blend:    layer.blend_mode,
          align:    layer.align,
          valign:   layer.valign,
          anchor:   layer.anchor,
          offset_x: layer.offset_x,
          offset_y: layer.offset_y,
          width:    layer.width,
          height:   layer.height
        }
      end

      def build_base_op(node)
        case node.source_type
        when :file     then build_load_op(node)
        when :solid    then build_solid_op(node)
        when :text     then build_text_op(node)
        when :gradient then build_gradient_op(node)
        end
      end

      def build_load_op(node)
        target_w, target_h, crop = nil, nil, nil

        if !node.trim && node.width.is_a?(Numeric)
          target_w, target_h = node.width, node.height
          crop = :centre if node.fit == :cover
        elsif node.trim && node.width.is_a?(Numeric) && node.width < 1000
          target_w = node.width * 2
        end

        Ops::Load.new(node.source, target_width: target_w, target_height: target_h, crop_mode: crop)
      end

      def build_solid_op(node)
        w = node.width.is_a?(Numeric) ? node.width : (@width_stack.last || 1)
        h = node.height.is_a?(Numeric) ? node.height : (@height_stack.last || 1)
        Ops::Solid.new(color: node.solid, width: w, height: h)
      end

      def build_text_op(node)
        w = node.width.is_a?(Numeric) ? node.width : nil
        Ops::Text.new(text: node.text, font: node.font || "sans", size: node.size || 24, color: node.color || "#000", width: w)
      end

      def build_gradient_op(node)
        w = node.width.is_a?(Numeric) ? node.width : (@width_stack.last || 1)
        h = node.height.is_a?(Numeric) ? node.height : (@height_stack.last || 1)
        Ops::Gradient.new(
          from: node.gradient[:from], to: node.gradient[:to], 
          direction: node.gradient[:direction] || :top_bottom,
          width: w, height: h
        )
      end

      def apply_effects(op, effects)
        effects.inject(op) { |current_op, effect| Ops::EffectOp.new(input: current_op, effect_node: effect) }
      end
    end
  end
end
